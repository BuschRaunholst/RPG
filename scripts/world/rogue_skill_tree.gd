extends RefCounted

const TREE := {
	"class_id": "rogue",
	"start_node_id": "rogue_start",
	"starter_active_family": "",
	"regions": [
		{
			"id": "start_core",
			"name": "Start / Core Rogue",
			"theme": "Core Rogue instincts and opening specialization",
			"node_ids": [
				"rogue_start", "light_footing", "quick_draw", "close_cut",
				"street_toughness", "duel_habit", "natural_tempo", "lowborn_killer"
			],
			"cluster_ids": ["fleet_basics", "street_instinct"],
			"entry_node_ids": ["rogue_start"],
			"exit_node_ids": ["duel_habit", "quick_draw", "close_cut"]
		},
		{
			"id": "bow_mastery",
			"name": "Bow Mastery",
			"theme": "Ranged pressure and bow specialization",
			"node_ids": ["loose_string", "drawn_string", "multi_shot_1", "multi_shot_2", "piercing_arrow_1", "rapid_nock", "hunters_rhythm", "deadeye_study", "predators_reach", "marked_volley_1", "eagle_eye"],
			"cluster_ids": [],
			"entry_node_ids": ["quick_draw"],
			"exit_node_ids": ["marked_volley_1", "predators_reach"]
		},
		{
			"id": "skirmish_mobility",
			"name": "Skirmish Mobility",
			"theme": "Movement, repositioning, and tempo",
			"node_ids": ["fleet_ankles", "smoke_step", "relentless_chase"],
			"cluster_ids": [],
			"entry_node_ids": ["light_footing"],
			"exit_node_ids": ["relentless_chase"]
		},
		{
			"id": "one_hand_duelist",
			"name": "One-Hand Duelist",
			"theme": "Strength-dexterity hybrid melee Rogue",
			"node_ids": [
				"street_steel", "wrist_strength", "cutthroat_pace", "duel_guard",
				"dash_slash_1", "dash_slash_2", "twin_fang_1", "twin_fang_2",
				"riposte_rhythm", "close_pressure", "street_duelist", "dirty_finish",
				"blood_duel", "knife_in_the_gap"
			],
			"cluster_ids": [],
			"entry_node_ids": ["close_cut"],
			"exit_node_ids": ["knife_in_the_gap", "blood_duel", "dirty_finish"]
		},
		{
			"id": "precision_crit",
			"name": "Precision Crit",
			"theme": "Crit and parry payoff",
			"node_ids": ["riposte_cut", "precision_weave", "marked_volley_1", "killer_focus", "perfect_opening"],
			"cluster_ids": [],
			"entry_node_ids": ["duel_habit"],
			"exit_node_ids": ["perfect_opening"]
		}
	],
	"clusters": [
		{
			"id": "fleet_basics",
			"region_id": "start_core",
			"name": "Fleet Basics",
			"outer_node_ids": ["rogue_start", "light_footing", "quick_draw", "close_cut", "street_toughness", "duel_habit"],
			"center_node_id": "natural_tempo",
			"completion_rule": "all_outer_nodes"
		},
		{
			"id": "street_instinct",
			"region_id": "start_core",
			"name": "Street Instinct",
			"outer_node_ids": ["rogue_start", "close_cut", "street_toughness", "duel_habit", "quick_draw", "light_footing"],
			"center_node_id": "lowborn_killer",
			"completion_rule": "all_outer_nodes"
		}
	],
	"nodes": {
		"rogue_start": {"name": "Rogue Start", "region_id": "start_core", "type": "start", "unlock_rule": "always", "connections": ["light_footing", "quick_draw", "close_cut", "duel_habit"], "cost": 0, "effects": {"dexterity": 1, "run_speed": 1}, "ui_text": "Begin as a Rogue."},
		"light_footing": {"name": "Light Footing", "region_id": "start_core", "type": "passive_minor", "unlock_rule": "adjacent", "connections": ["rogue_start", "fleet_ankles"], "cost": 1, "effects": {"dexterity": 1, "run_speed": 1}, "ui_text": "Gain Dexterity and Run Speed."},
		"quick_draw": {"name": "Quick Draw", "region_id": "start_core", "type": "passive_minor", "unlock_rule": "adjacent", "connections": ["rogue_start", "loose_string"], "cost": 1, "effects": {"dexterity": 1, "attack_speed": 2}, "ui_text": "Gain Dexterity and Attack Speed."},
		"close_cut": {"name": "Close Cut", "region_id": "start_core", "type": "passive_minor", "unlock_rule": "adjacent", "connections": ["rogue_start", "street_steel"], "cost": 1, "effects": {"strength": 1, "one_hand_damage": 3}, "ui_text": "Gain Strength and one-hand damage."},
		"street_toughness": {"name": "Street Toughness", "region_id": "start_core", "type": "passive_minor", "unlock_rule": "adjacent", "connections": ["duel_habit", "natural_tempo", "lowborn_killer"], "cost": 1, "effects": {"stamina": 1, "max_health": 6}, "ui_text": "Gain Stamina and Health."},
		"duel_habit": {"name": "Duel Habit", "region_id": "start_core", "type": "passive_minor", "unlock_rule": "adjacent", "connections": ["rogue_start", "street_toughness", "riposte_cut", "natural_tempo"], "cost": 1, "effects": {"parry": 2}, "ui_text": "Improve Parry."},
		"natural_tempo": {"name": "Natural Tempo", "region_id": "start_core", "type": "cluster_center", "unlock_rule": "cluster_complete", "cluster_id": "fleet_basics", "connections": [], "cost": 1, "effects": {"attack_speed": 5, "run_speed": 2, "crit": 3}, "ui_text": "Unlock by completing the Fleet Basics ring."},
		"lowborn_killer": {"name": "Lowborn Killer", "region_id": "start_core", "type": "cluster_center", "unlock_rule": "cluster_complete", "cluster_id": "street_instinct", "connections": [], "cost": 1, "effects": {"strength": 2, "dexterity": 2, "one_hand_damage": 6}, "ui_text": "Unlock by completing the Street Instinct ring."},
		"loose_string": {"name": "Loose String", "region_id": "bow_mastery", "type": "passive_minor", "unlock_rule": "adjacent", "connections": ["quick_draw", "drawn_string"], "cost": 1, "effects": {"bow_damage": 4}, "ui_text": "Increase Bow Damage."},
		"drawn_string": {"name": "Drawn String", "region_id": "bow_mastery", "type": "passive_minor", "unlock_rule": "adjacent", "connections": ["loose_string", "multi_shot_1", "piercing_arrow_1"], "cost": 1, "effects": {"dexterity": 1, "attack_speed": 2}, "ui_text": "Tighten your ranged tempo."},
		"multi_shot_1": {"name": "Multi Shot I", "region_id": "bow_mastery", "type": "active_unlock", "unlock_rule": "adjacent", "skill_family": "multi_shot", "skill_tier": 1, "connections": ["drawn_string", "rapid_nock", "multi_shot_2"], "cost": 1, "effects": {"bow_damage": 4}, "ui_text": "Unlock Multi Shot."},
		"multi_shot_2": {"name": "Multi Shot II", "region_id": "bow_mastery", "type": "active_upgrade", "unlock_rule": "adjacent", "skill_family": "multi_shot", "skill_tier": 2, "connections": ["multi_shot_1", "hunters_rhythm"], "cost": 1, "effects": {"bow_damage": 5, "attack_speed": 2}, "ui_text": "Improve Multi Shot with more pressure and speed."},
		"piercing_arrow_1": {"name": "Piercing Arrow I", "region_id": "bow_mastery", "type": "active_unlock", "unlock_rule": "adjacent", "skill_family": "piercing_arrow", "skill_tier": 1, "connections": ["drawn_string", "rapid_nock"], "cost": 1, "effects": {"bow_damage": 5}, "ui_text": "Unlock Piercing Arrow."},
		"rapid_nock": {"name": "Rapid Nock", "region_id": "bow_mastery", "type": "passive_notable", "unlock_rule": "adjacent", "connections": ["multi_shot_1", "piercing_arrow_1", "hunters_rhythm"], "cost": 1, "effects": {"attack_speed": 4, "bow_damage": 4}, "ui_text": "Fire and recover faster with bow skills."},
		"hunters_rhythm": {"name": "Hunter's Rhythm", "region_id": "bow_mastery", "type": "passive_notable", "unlock_rule": "adjacent", "connections": ["rapid_nock", "multi_shot_2", "predators_reach", "marked_volley_1", "deadeye_study", "eagle_eye"], "cost": 1, "effects": {"attack_speed": 4, "bow_damage": 6, "crit": 3}, "ui_text": "Strong bow and crit payoff."},
		"deadeye_study": {"name": "Deadeye Study", "region_id": "bow_mastery", "type": "passive_notable", "unlock_rule": "adjacent", "connections": ["hunters_rhythm", "predators_reach"], "cost": 1, "effects": {"crit": 5, "bow_damage": 4}, "ui_text": "Build precision and ranged execution."},
		"eagle_eye": {"name": "Eagle Eye", "region_id": "bow_mastery", "type": "passive_notable", "unlock_rule": "adjacent", "connections": ["hunters_rhythm", "marked_volley_1"], "cost": 1, "effects": {"crit": 4, "dexterity": 1}, "ui_text": "Sharpen ranged precision and target focus."},
		"predators_reach": {"name": "Predator's Reach", "region_id": "bow_mastery", "type": "keystone", "unlock_rule": "adjacent", "connections": ["hunters_rhythm"], "cost": 1, "effects": {"bow_damage": 10, "crit": 6}, "ui_text": "Major long-range bow payoff."},
		"fleet_ankles": {"name": "Fleet Ankles", "region_id": "skirmish_mobility", "type": "passive_notable", "unlock_rule": "adjacent", "connections": ["light_footing", "smoke_step"], "cost": 1, "effects": {"run_speed": 3, "dexterity": 1}, "ui_text": "Move faster and cleaner."},
		"smoke_step": {"name": "Smoke Step", "region_id": "skirmish_mobility", "type": "active_unlock", "unlock_rule": "adjacent", "skill_family": "smoke_step", "skill_tier": 1, "connections": ["fleet_ankles", "relentless_chase"], "cost": 1, "effects": {"run_speed": 2}, "ui_text": "Unlock Smoke Step."},
		"relentless_chase": {"name": "Relentless Chase", "region_id": "skirmish_mobility", "type": "keystone", "unlock_rule": "adjacent", "connections": ["smoke_step"], "cost": 1, "effects": {"run_speed": 4, "attack_speed": 3}, "ui_text": "Gain offense through motion."},
		"street_steel": {"name": "Street Steel", "region_id": "one_hand_duelist", "type": "passive_notable", "unlock_rule": "adjacent", "connections": ["close_cut", "wrist_strength", "cutthroat_pace", "duel_guard"], "cost": 1, "effects": {"strength": 1, "one_hand_damage": 8}, "ui_text": "Become deadlier with one-hand weapons."},
		"wrist_strength": {"name": "Wrist Strength", "region_id": "one_hand_duelist", "type": "passive_minor", "unlock_rule": "adjacent", "connections": ["street_steel", "dash_slash_1"], "cost": 1, "effects": {"strength": 1, "one_hand_damage": 3}, "ui_text": "Build stronger close-range weapon strikes."},
		"cutthroat_pace": {"name": "Cutthroat Pace", "region_id": "one_hand_duelist", "type": "passive_minor", "unlock_rule": "adjacent", "connections": ["street_steel", "twin_fang_1"], "cost": 1, "effects": {"dexterity": 1, "attack_speed": 2}, "ui_text": "Move and strike faster with one-hand weapons."},
		"duel_guard": {"name": "Duel Guard", "region_id": "one_hand_duelist", "type": "passive_minor", "unlock_rule": "adjacent", "connections": ["street_steel", "riposte_rhythm"], "cost": 1, "effects": {"parry": 2}, "ui_text": "Sharpen close-range guard and parry timing."},
		"dash_slash_1": {"name": "Dash Slash I", "region_id": "one_hand_duelist", "type": "active_unlock", "unlock_rule": "adjacent", "skill_family": "dash_slash", "skill_tier": 1, "connections": ["wrist_strength", "dash_slash_2"], "cost": 1, "effects": {"one_hand_damage": 5}, "ui_text": "Unlock Dash Slash."},
		"dash_slash_2": {"name": "Dash Slash II", "region_id": "one_hand_duelist", "type": "active_upgrade", "unlock_rule": "adjacent", "skill_family": "dash_slash", "skill_tier": 2, "connections": ["dash_slash_1", "blood_duel"], "cost": 1, "effects": {"one_hand_damage": 5, "attack_speed": 2}, "ui_text": "Sharpen Dash Slash into a faster, deadlier opener."},
		"twin_fang_1": {"name": "Twin Fang I", "region_id": "one_hand_duelist", "type": "active_unlock", "unlock_rule": "adjacent", "skill_family": "twin_fang", "skill_tier": 1, "connections": ["cutthroat_pace", "twin_fang_2"], "cost": 1, "effects": {"attack_speed": 4, "one_hand_damage": 5}, "ui_text": "Unlock Twin Fang."},
		"twin_fang_2": {"name": "Twin Fang II", "region_id": "one_hand_duelist", "type": "active_upgrade", "unlock_rule": "adjacent", "skill_family": "twin_fang", "skill_tier": 2, "connections": ["twin_fang_1", "dirty_finish"], "cost": 1, "effects": {"one_hand_damage": 6, "crit": 3}, "ui_text": "Turn Twin Fang into a nastier burst finisher."},
		"riposte_rhythm": {"name": "Riposte Rhythm", "region_id": "one_hand_duelist", "type": "passive_notable", "unlock_rule": "adjacent", "connections": ["duel_guard", "close_pressure"], "cost": 1, "effects": {"parry": 5, "attack_speed": 4}, "ui_text": "Build tempo from parries and close-range rhythm."},
		"close_pressure": {"name": "Close Pressure", "region_id": "one_hand_duelist", "type": "passive_minor", "unlock_rule": "adjacent", "connections": ["riposte_rhythm", "street_duelist"], "cost": 1, "effects": {"one_hand_damage": 4}, "ui_text": "Stay dangerous when fighting in tight range."},
		"street_duelist": {"name": "Street Duelist", "region_id": "one_hand_duelist", "type": "passive_notable", "unlock_rule": "adjacent", "connections": ["close_pressure", "blood_duel", "knife_in_the_gap"], "cost": 1, "effects": {"strength": 1, "dexterity": 1, "one_hand_damage": 6}, "ui_text": "Blend power and finesse into a dirty duel style."},
		"dirty_finish": {"name": "Dirty Finish", "region_id": "one_hand_duelist", "type": "passive_notable", "unlock_rule": "adjacent", "connections": ["twin_fang_2", "knife_in_the_gap"], "cost": 1, "effects": {"one_hand_damage": 8, "crit": 4}, "ui_text": "Punish wounded enemies with vicious close-range finishers."},
		"blood_duel": {"name": "Blood Duel", "region_id": "one_hand_duelist", "type": "keystone", "unlock_rule": "adjacent", "connections": ["dash_slash_2", "street_duelist"], "cost": 1, "effects": {"attack_speed": 8, "crit": 10, "defense": -10}, "ui_text": "Fight faster and deadlier up close, but become more fragile."},
		"knife_in_the_gap": {"name": "Knife in the Gap", "region_id": "one_hand_duelist", "type": "keystone", "unlock_rule": "adjacent", "connections": ["street_duelist", "dirty_finish"], "cost": 1, "effects": {"parry": 4, "one_hand_damage": 10}, "ui_text": "Massive melee payoff after a parry."},
		"riposte_cut": {"name": "Riposte Cut", "region_id": "precision_crit", "type": "passive_notable", "unlock_rule": "adjacent", "connections": ["duel_habit", "precision_weave"], "cost": 1, "effects": {"parry": 4, "crit": 4}, "ui_text": "Crit and parry payoff."},
		"precision_weave": {"name": "Precision Weave", "region_id": "precision_crit", "type": "passive_minor", "unlock_rule": "adjacent", "connections": ["riposte_cut", "marked_volley_1"], "cost": 1, "effects": {"crit": 3}, "ui_text": "Tighten precision through focused timing."},
		"marked_volley_1": {"name": "Marked Volley I", "region_id": "precision_crit", "type": "active_unlock", "unlock_rule": "adjacent", "skill_family": "marked_volley", "skill_tier": 1, "connections": ["hunters_rhythm", "precision_weave", "killer_focus", "eagle_eye"], "cost": 1, "effects": {"crit": 5, "bow_damage": 4}, "ui_text": "Unlock Marked Volley."},
		"killer_focus": {"name": "Killer Focus", "region_id": "precision_crit", "type": "passive_notable", "unlock_rule": "adjacent", "connections": ["marked_volley_1", "perfect_opening"], "cost": 1, "effects": {"crit": 5, "attack_speed": 3}, "ui_text": "Build execution windows after a marked hit."},
		"perfect_opening": {"name": "Perfect Opening", "region_id": "precision_crit", "type": "keystone", "unlock_rule": "adjacent", "connections": ["killer_focus"], "cost": 1, "effects": {"parry": 5, "crit": 8}, "ui_text": "Huge crit and parry payoff."}
	}
}
