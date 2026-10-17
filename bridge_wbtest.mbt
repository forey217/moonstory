///|
test "JSON bridge returns structured compiler errors" {
  guard @json.parse(run_json("{\"command\":\"check\",\"source\":\"wrong\"}"))
    is Object(o) else {
    fail("object")
  }
  assert_eq(o.get("ok"), Some(Json::boolean(false)))
  assert_eq(o.get("code"), Some(Json::string("syntax")))
  assert_eq(o.get("line"), Some(Json::number(1)))
}

///|
test "JSON bridge rejects malformed requests and exports structural metadata" {
  for bad in ["null", "[]", "{", "{}", "{\"command\":3}"] {
    guard @json.parse(run_json(bad)) is Object(o) else { fail("object") }
    assert_eq(o.get("ok"), Some(Json::boolean(false)))
  }
  let request = Json::object(
    Map([
      ("command", Json::string("check")),
      ("source", Json::string(shop_script)),
    ]),
  ).stringify()
  guard @json.parse(run_json(request)) is Object(o) else { fail("object") }
  assert_eq(o.get("ok"), Some(Json::boolean(true)))
  guard o.get("result") is Some(Object(r)) else { fail("result") }
  assert_eq(r.get("id"), Some(Json::string("shop")))
  assert_eq(r.get("diagnostics"), Some(Json::array([])))
}
