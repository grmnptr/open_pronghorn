//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

#pragma once

#include "GeneralPostprocessor.h"

/**
 * Computes the cylinder DRL reward used by the source Python environment.
 */
class CylinderDRLReward : public GeneralPostprocessor
{
public:
  static InputParameters validParams();

  CylinderDRLReward(const InputParameters & parameters);

  virtual void initialize() override {}
  virtual void execute() override;
  virtual PostprocessorValue getValue() const override;

protected:
  /// Drag coefficient postprocessor value
  const PostprocessorValue & _drag;

  /// Lift coefficient postprocessor value
  const PostprocessorValue & _lift;

  /// Number of transient timesteps in one action/reward window
  const unsigned int _timestep_window;

  /// Baseline reward shift
  const Real _drag_baseline;

  /// Lift penalty weight
  const Real _lift_weight;

  /// Value returned before the first completed reward window
  const Real _initial_reward;

  /// Accumulated drag coefficient over the current action window
  Real _drag_sum;

  /// Accumulated lift coefficient over the current action window
  Real _lift_sum;

  /// Number of samples accumulated in the current action window
  unsigned int _samples_in_window;

  /// Most recently completed reward
  PostprocessorValue _reward;
};
