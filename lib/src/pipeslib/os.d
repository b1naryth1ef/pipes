module pipelib.os;

import pipelib.global;
import core.sys.posix.dirent;
import core.sys.posix.sys.stat;
import core.stdc.string : strlen;
import core.stdc.stdlib : malloc;

extern (C) {
  struct DirectoryListingStream {
    DIR *dir;

    bool includeFiles;
    bool includeDirs;
    bool includeLinks;

    static Stream* create(PipeString* path) {
      auto memory = malloc(Stream.sizeof + DirectoryListingStream.sizeof);
      auto stream = cast(Stream*)memory;
      auto dls = cast(DirectoryListingStream*)&memory[Stream.sizeof];

      dls.dir = opendir(path.start);
      dls.includeFiles = false;
      dls.includeDirs = false;
      dls.includeLinks = false;

      stream.data = cast(void*)dls;
      stream.nextString = &streamDirectoryListingNextString;
      return stream;
    }
  }

  PipeString* streamDirectoryListingNextString(Stream* stream) {
    auto dls = (cast(DirectoryListingStream*)stream.data);

    // Stream is completed
    if (dls.dir is null) {
      return null;
    }

    dirent* ent;
    while (true) {
      ent = readdir(dls.dir);
      // If we don't have a entity complete the stream
      if (ent is null) {
        closedir(dls.dir);
        dls.dir = null;
        return null;
      }

      if (!dls.includeFiles || !dls.includeDirs || !dls.includeLinks) {
        stat_t statbuf;
        assert(stat(ent.d_name.ptr, &statbuf) != -1);

        if (dls.includeFiles && S_ISREG(statbuf.st_mode)) {
          break;
        } else if (dls.includeDirs && S_ISDIR(statbuf.st_mode)) {
          break;
        } else if (dls.includeLinks && S_ISLNK(statbuf.st_mode)) {
          break;
        }
      } else {
        break;
      }
    }

    return createPipeString(cast(immutable(char)*)ent.d_name.ptr, strlen(ent.d_name.ptr));
  }

  Stream* os_files(PipeString* path) {
    auto stream = DirectoryListingStream.create(path);
    auto dls = cast(DirectoryListingStream*)stream.data;
    dls.includeFiles = true;
    return stream;
  }

  Stream* os_dirs(PipeString* path) {
    auto stream = DirectoryListingStream.create(path);
    auto dls = cast(DirectoryListingStream*)stream.data;
    dls.includeDirs = true;
    return stream;
  }

  Stream* os_ls(PipeString* path) {
    auto stream = DirectoryListingStream.create(path);
    auto dls = cast(DirectoryListingStream*)stream.data;
    dls.includeDirs = true;
    dls.includeFiles = true;
    dls.includeLinks = true;
    return stream;
  }
}
