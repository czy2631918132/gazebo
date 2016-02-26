/*
 * Copyright (C) 2016 Open Source Robotics Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
*/

#include <chrono>
#include <map>
#include <set>
#include <thread>

#include <ignition/transport.hh>

#include "gazebo/msgs/msgs.hh"

#include "gazebo/common/Console.hh"
#include "gazebo/common/URI.hh"

#include "gazebo/util/IntrospectionClient.hh"

#include "gazebo/gui/plot/PlottingTypes.hh"
#include "gazebo/gui/plot/PlotCurve.hh"
#include "gazebo/gui/plot/IntrospectionCurveHandler.hh"

using namespace gazebo;
using namespace gui;

namespace gazebo
{
  namespace gui
  {
    /// \brief Private data for the IntrospectionCurveHandler class.
    class IntrospectionCurveHandlerPrivate
    {
      /// \def CurveVariableMapIt
      /// \brief Curve variable map iterator
      public: using CurveVariableMapIt =
          std::map<std::string, CurveVariableSet>::iterator;

      /// \brief Mutex to protect the introspection updates.
      public: std::mutex mutex;

      /// \brief A map of variable names to plot curves.
      public: std::map<std::string, CurveVariableSet> curves;

      /// \brief Introspection Client
      public: util::IntrospectionClient introspectClient;

      /// \brief Introspection manager Id
      public: std::string managerId;

      /// \brief Ign transport node.
      public: ignition::transport::Node ignNode;

      /// \brief Introspection thread.
      public: std::unique_ptr<std::thread> introspectThread;

      /// \brief Introspection filter.
      public: std::set<std::string> introspectFilter;

      /// \brief Number of subscribers to a introspection filter.
      public: std::map<std::string, int> introspectFilterCount;

      /// \brief Introspection filter ID.
      public: std::string introspectFilterId;

      /// \brief Introspection filter topic.
      public: std::string introspectFilterTopic;

      /// \brief The sim time variable string registered in the
      /// introspection manager.
      public: std::string simTimeVar = "data://world/default?p=sim_time";
    };
  }
}

/////////////////////////////////////////////////
IntrospectionCurveHandler::IntrospectionCurveHandler()
  : dataPtr(new IntrospectionCurveHandlerPrivate())
{
  // set up introspection client in another thread as it blocks on
  // discovery
  this->dataPtr->introspectThread.reset(
      new std::thread(&IntrospectionCurveHandler::SetupIntrospection, this));
}

/////////////////////////////////////////////////
IntrospectionCurveHandler::~IntrospectionCurveHandler()
{
  this->dataPtr->introspectThread->join();
}

/////////////////////////////////////////////////
void IntrospectionCurveHandler::SetupIntrospection()
{
  std::lock_guard<std::mutex> lock(this->dataPtr->mutex);

  // Wait for the managers to come online
  std::set<std::string> managerIds =
      this->dataPtr->introspectClient.WaitForManagers(std::chrono::seconds(2));
  if (managerIds.empty())
  {
    gzerr << "No introspection managers detected." << std::endl;
    return;
  }

  // get the first manager
  this->dataPtr->managerId = *managerIds.begin();

  if (this->dataPtr->managerId.empty())
  {
    gzerr << "Introspection manager ID is empty" << std::endl;
    return;
  }

  if (!this->dataPtr->introspectClient.IsRegistered(
      this->dataPtr->managerId, this->dataPtr->simTimeVar))
  {
    gzerr << "The sim_time item is not registered on the manager.\n";
    return;
  }

  std::set<std::string> items;
  this->dataPtr->introspectClient.Items(this->dataPtr->managerId, items);

  std::cerr << " items " << std::endl;
  for (auto i : items)
  {
    std::cerr << i << std::endl;
  }
  std::cerr << " ==== " << std::endl;

  // Let's create a filter for sim_time.
  this->dataPtr->introspectFilter = {this->dataPtr->simTimeVar};
  this->dataPtr->introspectFilterCount[this->dataPtr->simTimeVar] = 1;
  if (!this->dataPtr->introspectClient.NewFilter(
      this->dataPtr->managerId, this->dataPtr->introspectFilter,
      this->dataPtr->introspectFilterId, this->dataPtr->introspectFilterTopic))
  {
    gzerr << "Unable to create introspection filter" << std::endl;
    return;
  }

  // Subscribe to custom introspection topic for receiving updates.
  if (!this->dataPtr->ignNode.Subscribe(this->dataPtr->introspectFilterTopic,
      &IntrospectionCurveHandler::OnIntrospection, this))
  {
    gzerr << "Error subscribing to introspection manager" << std::endl;
    return;
  }
}

/////////////////////////////////////////////////
void IntrospectionCurveHandler::AddCurve(const std::string &_name,
    PlotCurveWeakPtr _curve)
{
  std::lock_guard<std::mutex> lock(this->dataPtr->mutex);
  auto c = _curve.lock();
  if (!c)
    return;

  auto it = this->dataPtr->curves.find(_name);
  if (it == this->dataPtr->curves.end())
  {
    // create entry in map
    CurveVariableSet curveSet;
    curveSet.insert(_curve);
    this->dataPtr->curves[_name] = curveSet;

    this->AddItemToFilter(_name);

  }
  else
  {
    auto cIt = it->second.find(_curve);
    if (cIt == it->second.end())
    {
      it->second.insert(_curve);
    }
  }
}

/////////////////////////////////////////////////
void IntrospectionCurveHandler::RemoveCurve(PlotCurveWeakPtr _curve)
{
  std::lock_guard<std::mutex> lock(this->dataPtr->mutex);
  auto c = _curve.lock();
  if (!c)
    return;

  // find and remove the curve
  for (auto it = this->dataPtr->curves.begin();
      it != this->dataPtr->curves.end(); ++it)
  {
    auto cIt = it->second.find(_curve);
    if (cIt != it->second.end())
    {
      it->second.erase(cIt);
      if (it->second.empty())
      {
        // remove item from introspection filter
        this->RemoveItemFromFilter(it->first);

        // erase from map
        this->dataPtr->curves.erase(it);
      }
      return;
    }
  }
}

/*
          common::URI uri(paramName);
          URIPath path = uri.Path();
          URIQuery query = uri.Query();
          while (query.Valid())
          {
            uri.SetQuery(query);
            uriStr = uri.Str();
            auto it = this->dataPtr->curves.find(uriStr);
            if (it == this->dataPtr->curves.end())
            {
              std::string queryStr = query.Str();
              size_t pos = queryStr.find("/");
              if (pos == std::string::npos);
                continue;
              queryStr = queryStr.substr(0, pos)
              query.Parse(queryStr);
            }
            else
            {
              break;
            }
          }

          if (!query.Valid())
            continue;
*/


/////////////////////////////////////////////////
void IntrospectionCurveHandler::OnIntrospection(
    const gazebo::msgs::Param_V &_msg)
{
  std::lock_guard<std::mutex> lock(this->dataPtr->mutex);

  // stores a list of curves iterators and their new values
  std::vector<
      std::pair<IntrospectionCurveHandlerPrivate::CurveVariableMapIt, double> >
      curvesUpdates;

  // collect data for updates
  double simTime = 0;
  bool hasSimTime = false;
  for (auto i = 0; i < _msg.param_size(); ++i)
  {
    auto param = _msg.param(i);
    if (param.name().empty() || !param.has_value())
      continue;

    std::string paramName = param.name();
    auto paramValue = param.value();

    // x axis is hardcoded to sim time for now
    if (!hasSimTime && paramName == this->dataPtr->simTimeVar)
    {
      if (paramValue.has_time_value())
      {
        common::Time t = msgs::Convert(paramValue.time_value());
        simTime = t.Double();
        hasSimTime = true;
      }
    }

    // std::cerr << "paramName " << paramName << std::endl;

    // see if there is a curve with variable name that matches param name or
    // a substring of the param name
    auto it = this->dataPtr->curves.find(paramName);
    if (it == this->dataPtr->curves.end())
    {
      for (auto cIt = this->dataPtr->curves.begin();
          cIt != this->dataPtr->curves.end(); ++cIt)
      {
        if (cIt->first.find(paramName) == 0)
        {
          it = cIt;
          break;
        }
      }
    }
    if (it == this->dataPtr->curves.end())
      continue;

    // get the data
    double data = 0;
    bool validData = true;
    std::string curveVarName = it->first;

    switch (paramValue.type())
    {
      case gazebo::msgs::Any::DOUBLE:
      {
        if (paramValue.has_double_value())
        {
          data = paramValue.double_value();
        }
        break;
      }
      case gazebo::msgs::Any::INT32:
      {
        if (paramValue.has_int_value())
        {
          data = paramValue.int_value();
        }
        break;
      }
      case gazebo::msgs::Any::BOOLEAN:
      {
        if (paramValue.has_bool_value())
        {
          data = static_cast<int>(paramValue.bool_value());
        }
        break;
      }
      case gazebo::msgs::Any::TIME:
      {
        if (paramValue.has_time_value())
        {
          common::Time t = msgs::Convert(paramValue.time_value());
          data = t.Double();
        }
        break;
      }
      case gazebo::msgs::Any::POSE3D:
      {
        if (paramValue.has_pose3d_value())
        {
          ignition::math::Pose3d p =
              msgs::ConvertIgn(paramValue.pose3d_value());

          double d = 0;
          // use uri to parse and get specific attribute
          common::URI uri(curveVarName);
          common::URIQuery query = uri.Query();
          std::string queryStr = query.Str();

          // example position query string:
          //   p=pose/world_pose/vector3/position/double/x
          // example rotation query string:
          //   p=pose/world_pose/vector3/orientation/double/roll
          // auto tokens = common::split(queryStr, "=/");
          // if (tokens.size() == 7u && tokens[1] == "pose")
          // {
          //  if (tokens[4] == "position")
          //    validData = Vector3dFromQuery(queryStr, p.Pos(), tokens[6]);
          //  else if (tokens[4] == "orientation")
          //    validData = Vector3dFromQuery(queryStr, p.Rot(), tokens[6]);
          //  else
          //    validData = false;
          //}
          //else
          //  validData = false;


          if (queryStr.find("position") != std::string::npos)
          {
            validData = Vector3dFromQuery(queryStr, p.Pos(), d);
          }
          else if (queryStr.find("orientation") != std::string::npos)
          {
            validData = QuaterniondFromQuery(queryStr, p.Rot(), d);
          }
          else
            validData = false;

          data = d;
        }
        else
          validData = false;
        break;
      }
      case gazebo::msgs::Any::VECTOR3D:
      {
        if (paramValue.has_vector3d_value())
        {
          ignition::math::Vector3d vec =
              msgs::ConvertIgn(paramValue.vector3d_value());

          double d = 0;
          // use uri to parse and get specific attribute
          common::URI uri(curveVarName);
          common::URIQuery query = uri.Query();
          std::string queryStr = query.Str();
          validData = Vector3dFromQuery(queryStr, vec, d);

          data = d;
        }
        else
          validData = false;
        break;
      }
      case gazebo::msgs::Any::QUATERNIOND:
      {
        if (paramValue.has_quaternion_value())
        {
          ignition::math::Quaterniond quat =
              msgs::ConvertIgn(paramValue.quaternion_value());

          double d = 0;
          // use uri to parse and get specific attribute
          common::URI uri(curveVarName);
          common::URIQuery query = uri.Query();
          std::string queryStr = query.Str();
          validData = QuaterniondFromQuery(queryStr, quat, d);

          data = d;
        }
        else
          validData = false;

        break;
      }
      default:
      {
        validData = false;
        break;
      }
    }
    if (!validData)
      continue;

    // push to tmp list and update later
    curvesUpdates.push_back(std::make_pair(it, data));
  }

  // update curves!
  for (auto &curveUpdate : curvesUpdates)
  {
    for (auto cIt : curveUpdate.first->second)
    {
      auto curve = cIt.lock();
      if (!curve)
        continue;
      curve->AddPoint(ignition::math::Vector2d(simTime, curveUpdate.second));
    }
  }

  return;
  // TODO remove later - for testing only
  auto it = this->dataPtr->curves.find("Dog");
  if (it != this->dataPtr->curves.end())
  {
    for (auto cIt : it->second)
    {
      auto curve = cIt.lock();
      if (!curve)
        continue;
      curve->AddPoint(ignition::math::Vector2d(simTime, 2));
    }
  }

  it = this->dataPtr->curves.find("Cat");
  if (it != this->dataPtr->curves.end())
  {
    for (auto cIt : it->second)
    {
      auto curve = cIt.lock();
      if (!curve)
        continue;
      curve->AddPoint(ignition::math::Vector2d(simTime, 10));
    }
  }

  it = this->dataPtr->curves.find("Turtle");
  if (it != this->dataPtr->curves.end())
  {
    for (auto cIt : it->second)
    {
      auto curve = cIt.lock();
      if (!curve)
        continue;
      curve->AddPoint(ignition::math::Vector2d(simTime, 6));
    }
  }
}

/////////////////////////////////////////////////
void IntrospectionCurveHandler::AddItemToFilter(const std::string &_name)
{
  common::URI itemURI(_name);

  if (!itemURI.Valid())
    return;

  common::URIPath itemPath = itemURI.Path();
  common::URIQuery itemQuery = itemURI.Query();

  std::set<std::string> items;
  this->dataPtr->introspectClient.Items(this->dataPtr->managerId, items);
  for (auto item : items)
  {
    std::cerr << "item: " << item << std::endl;
  }


  for (auto item : items)
  {
    common::URI uri(item);
    common::URIPath path = uri.Path();
    common::URIQuery query = uri.Query();

    // check if the entity matches
    if (itemPath == path)
    {
      // A registered variable can have the query
      //  "?p=world_pose"
      // and if the variable we are looking for has the query
      //  "?p=world_pose/position/x"
      // we need to add "scheme://path?world_pose" to the filter instead of
      // "scheme://path?p=world_pose/position/x"

      // check substring
      if (itemQuery.Str().find(query.Str()) == 0)
      {
        // add item to introspection filter
        if (this->dataPtr->introspectFilter.find(item) ==
            this->dataPtr->introspectFilter.end())
        {
          std::cerr << " adding filter ! " << uri.Str() << std::endl;
          this->dataPtr->introspectFilterCount[item] = 1;
          this->dataPtr->introspectFilter.insert(item);

          if (!this->dataPtr->introspectClient.UpdateFilter(
              this->dataPtr->managerId, this->dataPtr->introspectFilterId,
              this->dataPtr->introspectFilter))
          {
            gzerr << "Error updating introspection filter" << std::endl;
          }
        }
        else
        {
          // filter already exists, increment counter.
          int &count = this->dataPtr->introspectFilterCount[item];
          count++;
        }

        break;
      }
    }
  }
}

/////////////////////////////////////////////////
void IntrospectionCurveHandler::RemoveItemFromFilter(const std::string &_name)
{
  common::URI itemURI(_name);

  if (!itemURI.Valid())
    return;

  common::URIPath itemPath = itemURI.Path();
  common::URIQuery itemQuery = itemURI.Query();

  std::set<std::string> items;
  this->dataPtr->introspectClient.Items(this->dataPtr->managerId, items);

  for (auto item : items)
  {
    common::URI uri(item);
    common::URIPath path = uri.Path();
    common::URIQuery query = uri.Query();

    // check if the entity matches
    if (itemPath == path)
    {
      // A registered variable can have the query
      //  "?p=world_pose"
      // and if the variable we are looking for has the query
      //  "?p=world_pose/position/x"
      // we need to remove "scheme://path?world_pose" from the filter instead of
      // "scheme://path?p=world_pose/position/x"

      // check substring
      if (itemQuery.Str().find(query.Str()) == 0)
      {
        // remove item from introspection filter
        auto itemIt = this->dataPtr->introspectFilter.find(item);
        if (itemIt == this->dataPtr->introspectFilter.end())
        {
          return;
        }
        else
        {
          int &count = this->dataPtr->introspectFilterCount[item];
          count--;
          if (count == 0u)
          {
            this->dataPtr->introspectFilter.erase(itemIt);
            this->dataPtr->introspectFilterCount.erase(
                this->dataPtr->introspectFilterCount.find(item));

            if (!this->dataPtr->introspectClient.UpdateFilter(
                this->dataPtr->managerId, this->dataPtr->introspectFilterId,
                this->dataPtr->introspectFilter))
            {
              gzerr << "Error updating introspection filter" << std::endl;
            }
          }
        }
        break;
      }
    }
  }
}

/////////////////////////////////////////////////
bool IntrospectionCurveHandler::Vector3dFromQuery(const std::string &_query,
    const ignition::math::Vector3d &_vec, double &_value) const
{
  std::string elem = _query.substr(_query.size()-1);
  if (elem == "x")
  {
    _value = _vec.X();
  }
  else if (elem == "y")
  {
    _value= _vec.Y();
  }
  else if (elem == "z")
  {
    _value= _vec.Z();
  }
  else
    return false;

  return true;
}

/////////////////////////////////////////////////
bool IntrospectionCurveHandler::QuaterniondFromQuery(const std::string &_query,
    const ignition::math::Quaterniond &_quat, double &_value) const
{
  ignition::math::Vector3d euler = _quat.Euler();
  if (_query.find("roll") != std::string::npos)
  {
    _value = euler.X();
  }
  else if (_query.find("pitch") != std::string::npos)
  {
    _value = euler.Y();
  }
  if (_query.find("yaw") != std::string::npos)
  {
    _value = euler.Z();
  }
  else
    return false;

  return true;
}



/*/////////////////////////////////////////////////
void IntrospectionCurveHandler::AddCurve(const std::string &_name,
    PlotCurveWeakPtr _curve)
{
  std::lock_guard<std::mutex> lock(this->dataPtr->mutex);
  std::cerr << " querying filter items " << std::endl;
  std::set<std::string> items;
  this->dataPtr->introspectClient.Items(this->dataPtr->managerId, items);
  for (auto item : items)
  {
    std::cerr << "item: " << item << std::endl;
  }

  std::cerr << " updating filter " << std::endl;

  if (!this->dataPtr->introspectClient.UpdateFilter(
      this->dataPtr->managerId, this->dataPtr->introspectFilterId,
      this->dataPtr->introspectFilter))

  std::cerr << " done updating filter " << std::endl;
}

/////////////////////////////////////////////////
void IntrospectionCurveHandler::OnIntrospection(
    const gazebo::msgs::Param_V &_msg)
{
  std::cerr << " on intro " << std::endl;
  std::lock_guard<std::mutex> lock(this->dataPtr->mutex);
  std::cerr << " on intro pass lock " << std::endl;
  for (unsigned int i = 0; i < 10; ++i)
  {
    common::Time::MSleep(50);
  }
  std::cerr << " done intro " << std::endl;
}*/