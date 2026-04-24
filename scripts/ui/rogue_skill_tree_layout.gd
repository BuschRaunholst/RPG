extends RefCounted


static func get_layout() -> Dictionary:
	var node_positions := {
		"blood_duel": Vector2(1014.2, 104.8),
		"close_cut": Vector2(586.4, 261.7),
		"close_pressure": Vector2(1012.8, 203.0),
		"cutthroat_pace": Vector2(748.0, 301.4),
		"dash_slash_1": Vector2(813.5, 112.6),
		"dash_slash_2": Vector2(922.8, 107.8),
		"deadeye_study": Vector2(-19.9, 499.8),
		"dirty_finish": Vector2(1092.8, 329.8),
		"drawn_string": Vector2(323.0, 401.0),
		"duel_guard": Vector2(768.4, 223.0),
		"duel_habit": Vector2(559.9, 389.8),
		"eagle_eye": Vector2(286.0, 704.0),
		"fleet_ankles": Vector2(339.0, 212.9),
		"hunters_rhythm": Vector2(109.5, 534.3),
		"killer_focus": Vector2(165.4, 819.4),
		"knife_in_the_gap": Vector2(1182.2, 246.8),
		"light_footing": Vector2(415.5, 235.6),
		"loose_string": Vector2(359.0, 374.2),
		"lowborn_killer": Vector2(855.3, 357.0),
		"marked_volley_1": Vector2(215.7, 772.0),
		"multi_shot_1": Vector2(215.2, 418.3),
		"multi_shot_2": Vector2(286.0, 473.2),
		"natural_tempo": Vector2(737.7, 472.9),
		"perfect_opening": Vector2(77.0, 838.1),
		"piercing_arrow_1": Vector2(189.3, 409.1),
		"precision_weave": Vector2(365.0, 636.0),
		"predators_reach": Vector2(-74.1, 580.8),
		"quick_draw": Vector2(417.6, 347.0),
		"rapid_nock": Vector2(121.6, 443.0),
		"relentless_chase": Vector2(185.6, 163.7),
		"riposte_cut": Vector2(530.0, 508.6),
		"riposte_rhythm": Vector2(864.0, 236.2),
		"rogue_start": Vector2(500.0, 300.0),
		"smoke_step": Vector2(261.9, 183.8),
		"street_duelist": Vector2(1126.4, 137.0),
		"street_steel": Vector2(655.0, 230.6),
		"street_toughness": Vector2(699.5, 385.1),
		"twin_fang_1": Vector2(861.9, 320.6),
		"twin_fang_2": Vector2(990.0, 327.8),
		"wrist_strength": Vector2(706.8, 144.6)
	}
	var region_label_positions := {
		"start_core": Vector2(452.0, 166.0),
		"bow_mastery": Vector2(168.0, 252.0),
		"skirmish_mobility": Vector2(720.0, 120.0),
		"precision_crit": Vector2(962.0, 330.0),
		"one_hand_duelist": Vector2(730.0, 474.0)
	}

	return {
		"node_positions": node_positions,
		"region_label_positions": region_label_positions
	}
