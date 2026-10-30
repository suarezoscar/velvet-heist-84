## @file test_join_address.gd
## Dirección para unirse (#110): «ip:puerto», solo «ip» y los errores con su mensaje.
extends GutTest


func test_empty_means_local_default() -> void:
	var r: Dictionary = JoinAddress.parse("   ")
	assert_true(r["ok"])
	assert_eq(r["ip"], "127.0.0.1")
	assert_eq(r["port"], NetManagerNode.DEFAULT_PORT)


func test_only_ip_uses_default_port() -> void:
	var r: Dictionary = JoinAddress.parse("83.45.120.7")
	assert_true(r["ok"])
	assert_eq(r["ip"], "83.45.120.7")
	assert_eq(r["port"], NetManagerNode.DEFAULT_PORT)
	assert_eq(r["error"], "")


func test_ip_and_port() -> void:
	var r: Dictionary = JoinAddress.parse("83.45.120.7:9000")
	assert_true(r["ok"])
	assert_eq(r["ip"], "83.45.120.7")
	assert_eq(r["port"], 9000)


func test_spaces_around_are_ignored() -> void:
	var r: Dictionary = JoinAddress.parse("  10.0.0.5:8000  ")
	assert_true(r["ok"])
	assert_eq(r["ip"], "10.0.0.5")
	assert_eq(r["port"], 8000)


func test_port_out_of_range_fails() -> void:
	for text: String in ["1.2.3.4:80", "1.2.3.4:70000", "1.2.3.4:0"]:
		var r: Dictionary = JoinAddress.parse(text)
		assert_false(r["ok"], text)
		assert_eq(r["ip"], "")
		assert_eq(r["port"], 0)
		assert_string_contains(r["error"], "Ese puerto no vale")


func test_non_numeric_or_empty_port_fails() -> void:
	for text: String in ["1.2.3.4:abc", "1.2.3.4:"]:
		var r: Dictionary = JoinAddress.parse(text)
		assert_false(r["ok"], text)
		assert_string_contains(r["error"], "Ese puerto no vale")


func test_empty_ip_with_port_fails() -> void:
	var r: Dictionary = JoinAddress.parse(":7777")
	assert_false(r["ok"])
	assert_string_contains(r["error"], "IP:puerto")


func test_two_colons_fail() -> void:
	var r: Dictionary = JoinAddress.parse("1.2.3.4:7777:1")
	assert_false(r["ok"])
	assert_string_contains(r["error"], "IP:puerto")
