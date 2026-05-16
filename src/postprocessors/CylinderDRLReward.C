//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

#include "CylinderDRLReward.h"

#include <cmath>

registerMooseObject("OpenPronghornApp", CylinderDRLReward);

InputParameters
CylinderDRLReward::validParams()
{
  InputParameters params = GeneralPostprocessor::validParams();
  params.addClassDescription("Computes the windowed reward for the cylinder DRL environment as "
                             "drag_baseline - mean(drag) - lift_weight * abs(mean(lift)).");

  params.addRequiredParam<PostprocessorName>("drag", "Drag coefficient postprocessor.");
  params.addRequiredParam<PostprocessorName>("lift", "Lift coefficient postprocessor.");
  params.addRangeCheckedParam<unsigned int>(
      "timestep_window", 1, "timestep_window > 0", "Number of timesteps per action window.");
  params.addParam<Real>("drag_baseline", 3.205, "Baseline drag shift in the reward.");
  params.addParam<Real>("lift_weight", 0.2, "Weight for the absolute mean lift penalty.");
  params.addParam<Real>("initial_reward", 0.0, "Reward reported before the first complete window.");
  params.set<ExecFlagEnum>("execute_on") = {EXEC_INITIAL, EXEC_TIMESTEP_END};

  return params;
}

CylinderDRLReward::CylinderDRLReward(const InputParameters & parameters)
  : GeneralPostprocessor(parameters),
    _drag(getPostprocessorValue("drag")),
    _lift(getPostprocessorValue("lift")),
    _timestep_window(getParam<unsigned int>("timestep_window")),
    _drag_baseline(getParam<Real>("drag_baseline")),
    _lift_weight(getParam<Real>("lift_weight")),
    _initial_reward(getParam<Real>("initial_reward")),
    _drag_sum(0.0),
    _lift_sum(0.0),
    _samples_in_window(0),
    _reward(_initial_reward)
{
}

void
CylinderDRLReward::execute()
{
  if (_current_execute_flag == EXEC_INITIAL)
  {
    _drag_sum = 0.0;
    _lift_sum = 0.0;
    _samples_in_window = 0;
    _reward = _initial_reward;
    return;
  }

  if (_current_execute_flag != EXEC_TIMESTEP_END)
    return;

  _drag_sum += _drag;
  _lift_sum += _lift;
  ++_samples_in_window;

  if (_samples_in_window == _timestep_window)
  {
    const Real avg_drag = _drag_sum / _samples_in_window;
    const Real avg_lift = _lift_sum / _samples_in_window;

    _reward = _drag_baseline - avg_drag - _lift_weight * std::abs(avg_lift);
    _drag_sum = 0.0;
    _lift_sum = 0.0;
    _samples_in_window = 0;
  }
}

PostprocessorValue
CylinderDRLReward::getValue() const
{
  return _reward;
}
