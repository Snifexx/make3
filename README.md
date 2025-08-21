# make3

This libary is basically my take of [nob.h](https://github.com/tsoding/nob.h) in c3.
It's a single header file library to make your own build system in c3, for c3 (tecnically for everything...).
As the name suggests, it's a glorified make, being simpler as it doesn't require a whole separate language while
being more powerful.

This is intended to be used in stead of the default c3 packaging system, so it is completely independet from
`project.json`. For this reason it makes some assumptions about the project layout, hence it may differ from that
of `project.json` (although by basically nothing). More info at the [Usage](#usage) section


## Usage

As make3.c3 is a single file, you can include it in your root directory of your project.
Then compile and run make3.c3 with your build file ([See Examples](#examples)).
It will generate a `make3` executable.

From then onwards whenever you make a change in your build file and make3.c3, the `make3`
executable will automatically recognise it, rebuild and run itself.

Any command can be built in make3, meaning it can truly be a make alternative.
However, it also provides useful default functions that can be used for tests and library
packaging. Those default functions are what make assumption about project layout as said.


### Project Layout for defaults

As a basis for any default functionality, all the source code MUST reside in a `src` directory.
The following are the currently provided default functionality one might need for a build system.

- Tests:
    For tests, there's `make3::default_tests(String spath)`.

    It assumes there's a `build` directory in the root of the project.
    If not it'll make one if it can.
    
    The provided `spath` is the path to take tests from. Tests are all in form of simple
    c3 files. Each c3 file will be considered itself. All other files in `spath` will be ignored.

    > [!TIP]
    > For the time being the command to run tests also compiles all the source code, so if you're
    > building an executable... you better check you only have a single main function.
    > This will obviously patcher later, as commenting one main function out everytime is...
    > unconvenient to say the least.

- Libraries:
    For now there's support for only two types of libraries:
    
    - C libaries with corresponding c3i header files (normal c3 files are perfectly fine as well)
    - Single c3 file libraries, exactly like make3.c3

    The default functions to work with these are respectively:
    - `make3::BuildCmd.lib(&self, String lib)`
    - `make3::BuildCmd.shflib(&self, String lib)`

    Both of these do nothing else other than add required args for adding libraries to a normal
    c3c compile command.
    There MUST be a `libs` directory in the root of the project, otherwise they return a
    `NO_LIBS_DIR` fault.
    Also:
    - `lib` assumes the existence of a subdirectory in `libs` named after the `String lib` parameter,
      inside of which there must be a "libXXX" static or dynamic library (anything -l would pick up)
      and optionals c3i/c3 header files, or any file the `c3c compile` command would accept.
    - `shflib` assumes the only existence of a file named after the `String lib` parameter in the
      `libs` directory

Remember though: you can completely ignore these project layout requirements, as these are only
for defaults! You can easily just define a list of command to run, create your own logic and execute them!

## Examples
The [test-build.c3](test-build.c3) file is a starting point and basic example for a build file using make3.
After writing your own build file (I usually name mine build.c3... duh), if you're running make3 for the
first time you would run something like: 

```sh
c3c compile-run test-build.c3 make3.c3 -o make3
```

Of course, you can name the `test-build.c3` file differently, and the same applies for the resulting executable.
I just binded an alias in my shell for make3, but you do you.
From here onwards, even if you make changes to `test-build.c3` or even the `make3.c3` file, the executable will recognise
those changes and rebuild itself when runned, so there is no use to run the given command anymore.

Now a quick rundown of what everything does in [test-build.c3](test-build.c3):

```c
BuildCmd cmd;
cmd.tinit({
/*  "c3c", "compile",
    args[0],
    "-o", "test-build-exe" */
    "echo", "COMPILATION!"
});
```

I commented out a normal usage of a command, but for demonstration kept an echo.
Pretty straightforward stuff. BuildCmd is just a wrapper around a List{String} with
helper functions (like described [above](#project-layout-for-defaults)).

```c
// cmd.lib("libc");

BuildCmd test;
test.tinit({
    "echo", "TEST!"
});
```

Apart for another command definition we have the commented line with lib, which would add a liblibc.so or liblibc.a
from a `libs/libc` subdirectory with more c3 files.

```c
if (make3::@print_err(make3::@go_rebuild_urself(args))) return 1;
```

This is the must-have line. It's what, as the name suggests, triggres rebuilding of the executable

```c
  String arg = args.len > 1 ? args[1] : "";
  switch (arg) {
    case "tests":
    case "test":
      if (make3::@print_err(make3::run(test.build()))) return 2;
    default:
      if (make3::@print_err(make3::run(cmd.build()))) return 2;
  }
```

And finally this is a little template if we want to parse arguments and act accordingly.
Notice that:

- to run a command, you must "build" it first,
- and, you can "pretty print" the error you'd recieve from any faulty function.
  Nothing exceptional, it'll probably be improved later, as for now it's a simple
  eprint of the fault if there's one.



As you could see, the code is so simple and understable at first glance, that it kinda
feels overkill for me to have this whole rundown.

