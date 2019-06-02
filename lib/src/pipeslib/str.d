module pipelib.str;

import pipelib.global;
import core.sys.posix.dirent;
import core.sys.posix.sys.stat;
import core.stdc.string : strlen, strncmp;
import core.stdc.stdlib : malloc;

extern (C) {
  bool str_endswith(PipeString* base, PipeString* match) {
    if (base.length >= match.length) {
      return strncmp(base.start + (base.length - match.length), match.start, match.length) == 0;
    } else {
      return false;
    }
  }
}
