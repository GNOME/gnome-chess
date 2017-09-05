tests = [
  'test-chess-game',
  'test-chess-pgn',
]

tests_vala_args = [
  '--target-glib=@0@'.format(min_glib_version),
]

tests_c_args = [
  '-include', 'config.h',
]

tests_deps = [
  glib,
  gio,
  libchess_dep,
]

foreach _test: tests
  test_bin = executable(_test,
    '@0@.vala'.format(_test),
    include_directories: config_h_dir,
    vala_args: tests_vala_args,
    c_args: tests_c_args,
    dependencies: tests_deps,
    install: true,
  )

  test(_test, test_bin)
endforeach
