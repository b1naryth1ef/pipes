module pipelib.os;

import pipelib.global;
import core.sys.posix.dirent;
import core.sys.posix.sys.stat;
import core.stdc.string : strlen;
import core.stdc.stdlib : malloc;

extern (C) {
  struct DirectoryListingStream {
    PipeString* path;
    DIR *dir;

    bool includeFiles;
    bool includeDirs;
    bool includeLinks;

    static Stream* create(PipeString* path) {
      auto memory = malloc(Stream.sizeof + DirectoryListingStream.sizeof);
      auto stream = cast(Stream*)memory;
      auto dls = cast(DirectoryListingStream*)&memory[Stream.sizeof];

      dls.path = path;
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

    // Prepare a buffer with our initial directory path prefixed
    char[512] path;
    memcpy(&path[0], dls.path.start, dls.path.length);

    // If no dir is set that means this stream is completed
    if (dls.dir is null) {
      return null;
    }

    dirent* ent;
    while (true) {
      ent = readdir(dls.dir);

      // If no entity was read we've completed listing the directory and can mark
      //  this stream as completed.
      if (ent is null) {
        closedir(dls.dir);
        dls.dir = null;
        return null;
      }

      // Fast path if we're not filtering by entity type
      if (!dls.includeFiles || !dls.includeDirs || !dls.includeLinks) {
        stat_t statbuf;

        // Fill out our buffer with the rest of the path
        snprintf(&path[dls.path.length], 512 - dls.path.length, "/%s", ent.d_name.ptr);
        cassert(stat(cast(const(char*))&path, &statbuf) != -1);

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

    return createPipeString(cast(immutable(char)*)&path[0], strlen(&path[0]));
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

  double os_file_size(PipeString* path) {
    stat_t st;
    stat(path.start, &st);
    return st.st_size;
  }

}
