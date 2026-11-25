class_name Fmt
## Formato de números para la interfaz (puntajes grandes incluidos).


## 1234 -> "1.234" · 12_345_678 -> "12,3 M" · 4.5e9 -> "4,5 MM" · 1.2e15 -> "1,20e15"
static func score(n: float) -> String:
	var neg := n < 0.0
	n = absf(n)
	var text: String
	if n < 1e6:
		text = _thousands(int(round(n)))
	elif n < 1e9:
		text = _dec(n / 1e6) + " M"
	elif n < 1e12:
		text = _dec(n / 1e9) + " MM"
	else:
		var e := int(floor(log(n) / log(10.0)))
		text = ("%.2f" % (n / pow(10.0, e))).replace(".", ",") + "e%d" % e
	return ("-" if neg else "") + text


static func _dec(x: float) -> String:
	if x >= 100.0:
		return str(int(x))
	return ("%.1f" % x).replace(".", ",")


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out


## Multiplicadores: 1 -> "1", 1.5 -> "1,5", 2.25 -> "2,25"
static func mult(x: float) -> String:
	if is_equal_approx(x, round(x)):
		return str(int(round(x)))
	return str(snappedf(x, 0.01)).replace(".", ",")
