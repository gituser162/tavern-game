import sys,re
p=sys.argv[1]
s=open(p,encoding='utf-8').read()
a=s.index("func _paid_bbcode(")
b=s.index("\n\n\nfunc ", a)
new='''func _paid_bbcode(id: String, uid: int = 0) -> String:
	var list: Array[Dictionary] = []
	if uid > 0 and not GameState.storage.origin_of(uid).is_empty():
		list.append(GameState.storage.origin_of(uid))
	else:
		list = GameState.storage.origins_of(id)
	if list.is_empty():
		return ""
	var crafted := true
	var paid: Array[int] = []
	for o in list:
		crafted = crafted and o["k"] == "craft"
		if o["c"] > 0:
			paid.append(o["c"])
	var free_n := list.size() - paid.size()
	if paid.is_empty():
		var free := "зварено з дармових інгредієнтів" if crafted else "дісталось задарма"
		return "[color=#b8a48c]Закупівля:[/color] %s" % free
	var label := "Собівартість (інгредієнти)" if crafted else "Куплено за"
	paid.sort()
	var lo: int = paid[0]
	var hi: int = paid[-1]
	var total := 0
	for c in paid:
		total += c
	var text: String
	if lo == hi:
		text = _m(lo) + (" за шт." if list.size() > 1 else "")
	else:
		text = "%d–%s за шт., у середньому %s" % [lo, _m(hi), _m(roundi(float(total) / paid.size()))]
	if free_n > 0:
		text += "  [color=#8a7a6a](ще %d шт. дісталось задарма)[/color]" % free_n
	return "[color=#b8a48c]%s:[/color] %s" % [label, text]'''
s=s[:a]+new+s[b:]
open(p,'w',encoding='utf-8',newline='\n').write(s)
print("ok")
