module make3;
import std::io;
import std::os;
import std::collections;
import libc;

enum CliEvent: char {
  DEFAULT,
  TEST,
}

faultdef NO_LIBS_DIR;
faultdef BUILD_FAILED;

interface Cmd {
  fn String[] build();
}

struct BuildCmd (Cmd) {
  List {String} args;
  Allocator all;
}

struct BuildCmdOpt {
  inline SubProcessOptions popt;
  bool nostrip_cmd_log;
}

fn BuildCmd* BuildCmd.tinit(&self, String[] init) @inline @dynamic {
  return self.init(tmem, init);
}

fn BuildCmd* BuildCmd.init(&self, Allocator all, String[] init) @dynamic {
  self.all = all;
  self.args.init_with_array(all, init);
  return self;
}

fn BuildCmd*? BuildCmd.libshf(&self, String lib) {
  if (!path::is_dir(path::temp("libs")!!)) return NO_LIBS_DIR?;
  self.args.push(string::format(self.all, "libs/%s", lib));
  return self;
}

fn BuildCmd*? BuildCmd.lib_given(&self, String lib) {
  if (!path::is_dir(path::temp("libs")!!)) return NO_LIBS_DIR?;
  self.args.push("-l");
  self.args.push(lib);
  self.args.push(string::format(self.all, "libs/%s/*", lib));
  return self;
}

fn BuildCmd*? BuildCmd.lib(&self, String lib) {
  if (!path::is_dir(path::temp("libs")!!)) return NO_LIBS_DIR?;
  self.args.push("-l");
  self.args.push(lib);
  self.args.push("-L");
  self.args.push(string::format(self.all, "libs/%s", lib));
  self.args.push(string::format(self.all, "libs/%s/*", lib));
  return self;
}

fn BuildCmd*? BuildCmd.nix_env(&self) {
  String nixenv = string::tformat("-Wl,%s", env::tget_var("NIX_LDFLAGS"))!;
  self.args.push("-z");
  self.args.push(nixenv);
  return self;
}

fn String[] BuildCmd.build(&self) @dynamic {
  return self.args.to_array(self.all);
}

macro @go_rebuild_urself(#args) {
  return go_rebuild_urself(#args, $$FILEPATH, "make3.c3");
}

fn bool? should_rebuild(String binary_path, String[] listened_files) {
  Stat binary_stat;
  if (catch res = os::native_stat(&binary_stat, binary_path)) {
    // If binary does not exist it must rebuild
    io::print("Error getting stat for binary file: ");
    io::printn(res);
    io::printn("Hence should rebuild...");
    return true;
  }
  
  foreach (file : listened_files) {
    Stat listened_stat;
    if (catch res = os::native_stat(&listened_stat, file)) {
      io::print("Error getting stat for listened file: ");
      io::printn(res);
      return res?;
    }
    if (listened_stat.st_mtime > binary_stat.st_mtime) return true;
  }

  return false;
}

fn void? go_rebuild_urself(String[] args, String listened_file, String make3_path) {
  if (!should_rebuild(args[0], { listened_file, make3_path })!) return;

  io::printn("REBUILDING TRIGGERED!");

  List{String} cmd;
  cmd.tinit_with_array({
    "c3c", "compile-run", listened_file, make3_path, "-o", args[0] 
  });
  if (args.len > 1) {
    cmd.push("--");
    cmd.add_array(args[1..]);
  }
  SubProcess? process = process::create(
    cmd.to_tarray(),
    { .inherit_environment = true, .no_window = true, .inherit_stdio = true, }
  );

  if (catch err = process) {
    io::printfn("Rebuilding process failed: %s", err);
    return err?;
  }
  
  io::printn("REBUILDING MYSELF...");

  int res = process.join()!;

  if (res != 0) {
    io::printfn("Rebuilding failed with opcode %d", res);
    return BUILD_FAILED?;
  }

  os::exit(0);
}

fn int? run(String[] cmd, BuildCmdOpt opt = {
    .inherit_environment = true,
    .no_window = true,
  }, bool silent = false) {
  opt.inherit_stdio = !silent;
  SubProcess process = process::create(cmd, opt)!;
  
  if (!silent) {
    io::printn("Created build process");
    io::printn("Running build process...\n");
  }

  int res = process.join()!;

  if (!silent) {
    io::print("\nExecuted command '");
    DString strcmd;
    strcmd.tinit().appendf("%s", cmd);
    if (!opt.nostrip_cmd_log && strcmd.len() > 1000) {
      strcmd.chop(200);
      strcmd.append("...]");
    }
    io::print(strcmd);
    io::print("' with exit code ");
    io::printn(res);
  }

  return res;
}

fn String[] PathList.to_targs(PathList self) {
  Path[] paths = self.to_tarray();
  String[] args = allocator::new_array(tmem, String, paths.len);
  foreach (i, path : paths) {
    args[i] = path.str_view();
  }
  return args;
}

fn PathList? wildcard(Allocator all, String wildcard) {
  BuildCmd cmd;
  cmd.tinit({ "fish", "-c", string::tformat("echo %s", wildcard) });
  SubProcess process = process::create(cmd.build(), {
    .inherit_environment = true,
    .no_window = true,
  })!;

  DString result;
  result.init(all);
  TeeReader pipe = io::tee_reader(&&process.stdout(), &result);

  usz read = 1;
  char[1024] buf;
  while (process.is_running()! || read != 0) read = pipe.read(&buf)!;

  int res = process.join()!;

  PathList pathlist;
  pathlist.init(all);
  String[] paths = result.str_view().tsplit(" ");
  foreach (path : paths) {
    pathlist.push(path::new(all, path)!!);
  }

  return pathlist;
}

fn int? default_tests(String spath, String[] args) {
  path::mkdir(path::temp("build")!!)!;
  PathList test_files = path::ls(tmem, path::temp(spath)!!, mask: "")!;
  test_files.retain_if(fn (it) { return (it.extension() == "c3") ?? false; });

  int failed;
  foreach (Path file : test_files) {
    String path = file.basename();

    BuildCmd cmd;
    String rel_path = string::tformat("%s/%s", spath, file); 
    cmd.tinit({ "c3c", "compile-run", rel_path, "-o", string::tformat("build/%s.test", rel_path) });
    cmd.args.add_array(args);

    int res = run(cmd.build(), silent: false)!;

    if (!res) {
      io::print("[✓]");
    } else {
      io::print("[✗]");
      failed++;
    }
    io::printfn(" Run test from \"%s\" with exit code %d", path, res);
  }

  io::printfn("\nFinished running all tests.\nFailed tests: %d", failed);
  return failed;
}

module utils;

alias HandledMainFn = fn int?(String[]);
import std::io;

fn int main_handle(String[] args, HandledMainFn handled_main, int err_code) {
  int? ret = handled_main(args);
  if (catch err = ret) {
    io::eprintn(err);
    return err_code;
  }
  return ret;
}

macro @print_err(#res) {
  if (catch err = #res) {
    io::eprintn(err);
    return true;
  }
  return false;
}
