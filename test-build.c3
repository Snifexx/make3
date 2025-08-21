module build;
import make3;

fn int main(String[] args) {
  BuildCmd cmd;
  cmd.tinit({/*
    "c3c", "compile",
    args[0],
    "-o", "test-build-exe" 
  */"echo", "COMPILATION!"
  });
  // cmd.lib("libc");

  BuildCmd test;
  test.tinit({
    "echo", "TEST!"
  });

  if (make3::@print_err(make3::@go_rebuild_urself(args))) return 1;
  String arg = args.len > 1 ? args[1] : "";
  switch (arg) {
    case "tests":
    case "test":
      if (make3::@print_err(make3::run(test.build()))) return 2;
    default:
      if (make3::@print_err(make3::run(cmd.build()))) return 2;
  }
	return 0;
}
