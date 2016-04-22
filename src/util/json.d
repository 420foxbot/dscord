module util.json;

import std.variant;
public import std.json;

import util.errors;

JSONObject[] fromJSONArray(string raw) {
  JSONObject[] result;

  auto data = parseJSON(raw);

  foreach (ref JSONValue value; data.array) {
    result ~= new JSONObject(value);
  }

  return result;
}

class JSONObject {
  Variant[string] obj;

  this() {}

  this(JSONValue v) {
    this.load(v);
  }

  this(string raw){
    this.loads(raw);
  }

  JSONObject loads(string raw) {
    return this.load(parseJSON(raw));
  }

  JSONObject load(JSONValue data) {
    foreach (string key, ref JSONValue value; data.object) {
      this.obj[key] = jsonToVariant(value);
    }
    return this;
  }

  JSONValue asJSON() {
    int[string] hack;
    auto res = JSONValue(hack);

    foreach (string key, ref Variant value; this.obj) {
      res.object[key] = variantToJSON(value);
    }

    return res;
  }

  string dumps() {
    JSONValue v = this.asJSON();
    return toJSON(v, true);
  }

  Variant getRaw(string key) {
    return this.obj[key];
  }

  T get(T)(string key) {
    return this.obj[key].coerce!(T);
  }

  T get(T)(string key, T def=cast(T)null) {
    if (key in this.obj) {
      return this.obj[key].coerce!(T);
    } else {
      return def;
    }
  }

  T maybeGet(T)(string key, T def) {
    if (!this.has(key) || this.isNull(key)) {
      return def;
    }

    return this.get!T(key);
  }

  JSONObject setRaw(string key, Variant value) {
    this.obj[key] = value;
    return this;
  }

  JSONObject setRaw(string key, JSONValue value) {
    this.obj[key] = jsonToVariant(value);
    return this;
  }

  JSONObject set(T)(string key, T value) {
    this.obj[key] = value;
    return this;
  }

  bool has(string key) {
    return (key in this.obj) != null;
  }

  bool isNull(string key) {
    return (this.obj[key].type == typeid(null));
  }

  Variant opIndex(string key) {
    return this.obj[key];
  }

  string[] getKeys() {
    string[] result;

    foreach (string key, ref Variant v; this.obj) {
      result ~= key;
    }

    return result;
  }
}

// Converts a Variant array to a JSONValue array
JSONValue convertVariantArray(Variant v) {
  JSONValue[] result;

  foreach (Variant i; v) {
    result ~= variantToJSON(i);
  }

  return JSONValue(result);
}

// Converts a Variant type to a JSONValue type
JSONValue variantToJSON(Variant v) {
  if (v.type == typeid(null)) {
    return JSONValue(null);
  } else if (v.convertsTo!string) {
    return JSONValue(v.get!string);
  } else if (v.convertsTo!wstring) {
    return JSONValue(v.get!wstring);
  } else if (v.convertsTo!uint) {
    return JSONValue(v.get!uint);
  } else if (v.convertsTo!int) {
    return JSONValue(v.get!int);
  } else if(v.convertsTo!float) {
    return JSONValue(v.get!float);
  } else if (v.convertsTo!bool) {
    return JSONValue(v.get!bool);
  } else if (v.convertsTo!double) {
    return JSONValue(v.get!double);
  } else if (v.type == typeid(JSONObject)) {
    JSONValue result;

    foreach (a, b; v.get!(JSONObject).obj) {
      result[a] = variantToJSON(b);
    }
    return result;
  }

  try {
    assert(v.length >= 0);
    return convertVariantArray(v);
  } catch (Exception) {}

  throw new BaseError("Failed to convert Variant (%s: %s) to JSONValue", v, v.type);
}

// Converts a JSONValue type to a Variant type
Variant jsonToVariant(JSONValue v) {
  switch (v.type) {
    case JSON_TYPE.NULL:
      return Variant(null);
    case JSON_TYPE.STRING:
      return Variant(v.str);
    case JSON_TYPE.INTEGER:
      return Variant(v.integer);
    case JSON_TYPE.UINTEGER:
      return Variant(v.uinteger);
    case JSON_TYPE.FLOAT:
      return Variant(v.floating);
    case JSON_TYPE.ARRAY:
      Variant[] data;

      foreach (JSONValue i; v.array) {
        data ~= jsonToVariant(i);
      }
      return Variant(data);
    case JSON_TYPE.TRUE:
      return Variant(true);
    case JSON_TYPE.FALSE:
      return Variant(false);
    case JSON_TYPE.OBJECT:
      return Variant(new JSONObject(v));
    default:
      throw new BaseError("Invalid JSONValue type %s", v.type);
  }
}
