/**
  Utility types that wrap specific utility functionality, without directly
  representing data/modeling from Discord.
*/
module dscord.types.util;

import dscord.types.message;

import std.format,
       std.array,
       std.conv,
       std.algorithm.sorting;

/**
  Utility class for constructing messages that can be sent over discord, allowing
  for inteligent limiting of size and stripping of formatting characters.
*/
class MessageBuffer : Sendable {
  private {
    bool codeBlock;
    bool filter;
    size_t _maxLength;
    string[] lines;
  }

  /**
    Params:
      codeBlock = if true, this message will be sent within a codeblock
      filter = if true, appended lines will be filtered for codeblocks/newlines
      maxLength = maximum length of this message, defaults to 2000
  */
  this(bool codeBlock = true, bool filter = true, size_t maxLength = 2000) {
    this.codeBlock = codeBlock;
    this.filter = filter;
    this._maxLength = maxLength;
  }

  immutable(string) toSendableString() {
    return this.contents;
  }

  /// Remove the last line in the buffer
  string popBack() {
    string line = this.lines[$-1];
    this.lines = this.lines[0..$-2];
    return line;
  }

  /// Max length of this message (subtracting for formatting)
  @property size_t maxLength() {
    size_t value = this._maxLength;

    // Codeblock backticks
    if (this.codeBlock) {
      value -= 6;
    }

    // Newlines
    value -= this.lines.length;

    return value;
  }

  /**
    Current length of this message (without formatting)
  */
  @property size_t length() {
    size_t len;

    foreach (line; lines) {
      len += line.length;
    }

    return len;
  }

  /**
    Formatted contents of this message.
  */
  @property string contents() {
    string contents = this.lines.join("\n");

    // Only format as a codeblock if we actually have contents
    if (this.codeBlock && contents.length) {
      return "```" ~ contents ~ "```";
    }

    return contents;
  }

  /**
    Append a line to this message. Returns false if the buffer is full.
  */
  bool append(string line) {
    string raw = line;

    // TODO: make this smarter
    if (this.filter) {
      raw = raw.replace("`", "").replace("\n", "");
    }

    if (this.length + raw.length > this.maxLength) {
      return false;
    }

    this.lines ~= raw;
    return true;
  }

  /**
    Format and append a line to this message. Returns false if the buffer is
    full.
  */
  bool appendf(T...)(string fmt, T args) {
    return this.append(format(fmt, args));
  }
}

/**
  Utility class for constructing tabulated messages.
*/
class MessageTable : Sendable {
  private {
    string[] header;
    string[][] entries;
    size_t[] sizes;
    string delim;
    bool wrapped;
  }

  // Message buffer used to compile the message
  MessageBuffer buffer;

  /**
    Creates a new MessageTable

    Params:
      delim = deliminator to use between table columns
      wrapped = whether to place a deliminator at the left/right margins
  */
  this(string delim=" | ", bool wrapped=true, MessageBuffer buffer=null) {
    this.delim = delim;
    this.wrapped = wrapped;
    this.buffer = buffer;
  }

  immutable(string) toSendableString() {
    if (!this.buffer) this.buffer = new MessageBuffer;
    if (!this.buffer.length) this.appendToBuffer(this.buffer);
    return buffer.toSendableString();
  }

  /**
    Sort entries by column. Column must be integral.

    Params:
      column = column index to sort by (0 based)
  */
  void sort(ulong column, int delegate(string) conv=null) {
    if (conv) {
      this.entries = std.algorithm.sorting.sort!(
        (a, b) => conv(a[column]) < conv(b[column])
      )(this.entries.dup).array;
    } else {
      this.entries = std.algorithm.sorting.sort!(
        (a, b) => a[column] < b[column])(this.entries.dup).array;
    }
  }

  /**
    Set a header row. Will not be sorted or modified.
  */
  void setHeader(string[] args...) {
    this.header = this.indexSizes(args.dup);
  }

  /// Resets sizes index for a given row
  private string[] indexSizes(string[] row) {
    size_t pos = 0;

    foreach (part; row) {
      ulong size = to!wstring(part).length;

      if (this.sizes.length <= pos) {
        this.sizes ~= size;
      } else if (this.sizes[pos] < size) {
        this.sizes[pos] = size;
      }
      pos++;
    }
    return row;
  }

  /**
    Add a row to the table.

    Params:
      args = sorted columns
  */
  void add(string[] args...) {
    this.entries ~= this.indexSizes(args.dup);
  }

  string compileEntry(string[] entry) {
    size_t pos;
    string line;

    // If we're wrapped, add left margin deliminator
    if (this.wrapped) line ~= this.delim;

    foreach (part; entry) {
      ulong size = to!wstring(part).length;
      line ~= part ~ " ".replicate(this.sizes[pos] - size) ~ this.delim;
      pos++;
    }

    // If we're not wrapped, remove the end deliminator
    if (!this.wrapped) line = line[0..($ - this.delim.length)];

    return line;
  }

  /// Appends the output of this table to a message buffer
  void appendToBuffer(MessageBuffer buffer) {
    foreach (entry; this.header ~ this.entries) {
      buffer.append(this.compileEntry(entry));
    }
  }

  string[][] iterEntries() {
    return this.header ~ this.entries;
  }
}
