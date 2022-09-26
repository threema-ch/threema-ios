# Project
project('saltyrtc-task-relayed-data-ffi-tests', 'c', default_options : ['c_std=c99'])

# Configure compiler
add_global_arguments(
  '-Wall',
  '-Wextra',
  '-Wpedantic',
  '-Werror',
  language: 'c'
)
if meson.get_compiler('c').get_id() == 'clang'
  add_global_arguments(
    '-Weverything',
    '-Wno-padded',
    language: 'c'
  )
endif

# Dependency: SaltyRTC
compiler = meson.get_compiler('c')
rust_target_dir = join_paths(meson.source_root(), 'target/debug/')
saltyrtc_task_relayed_data_ffi = compiler.find_library(
  'saltyrtc_task_relayed_data_ffi',
  dirs : [rust_target_dir]
)

# Dependency: pthread
thread_dep = dependency('threads')

# Executables
executable(
  'integration',
  'tests/integration.c',
  dependencies : [saltyrtc_task_relayed_data_ffi, thread_dep]
)
executable(
  'disconnect',
  'tests/disconnect.c',
  dependencies : [saltyrtc_task_relayed_data_ffi, thread_dep]
)
