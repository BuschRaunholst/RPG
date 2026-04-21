extends RefCounted


func find_best_attack_target(search_root: Node, origin: Vector2, direction: Vector2, attack_distance: float) -> Node:
	if search_root == null:
		return null

	var best_target: Node = null
	var best_score: float = -1.0
	var facing: Vector2 = direction.normalized()

	if facing.length() == 0.0:
		facing = Vector2.DOWN

	for child in search_root.get_children():
		if not child.is_in_group("enemies"):
			continue
		if not is_instance_valid(child):
			continue
		if bool(child.get("defeated_state")):
			continue

		var enemy_node := child as Node2D
		if enemy_node == null:
			continue

		var offset: Vector2 = enemy_node.global_position - origin
		var distance: float = offset.length()
		if distance > attack_distance or distance == 0.0:
			continue

		var alignment: float = facing.dot(offset.normalized())
		if alignment < 0.2:
			continue

		var score: float = alignment - (distance / attack_distance) * 0.35
		if score > best_score:
			best_score = score
			best_target = child

	return best_target


func is_use_interactable(target: Node) -> bool:
	if target == null:
		return false

	var npc_id: Variant = target.get("npc_id")
	if npc_id != null and not str(npc_id).is_empty():
		return false

	var npc_name: Variant = target.get("npc_name")
	if npc_name != null and not str(npc_name).is_empty():
		return false

	return true


func is_pickup_interactable(target: Node) -> bool:
	return target != null and target.has_method("collect_pickup")


func resolve_context_action(dialogue_open: bool, can_attack: bool, has_attack_target: bool, nearby_target: Node) -> String:
	if dialogue_open:
		return "next"

	if can_attack and has_attack_target:
		return "attack"

	if is_pickup_interactable(nearby_target):
		return "pick_up"

	if nearby_target != null and is_use_interactable(nearby_target):
		return "use"

	if nearby_target != null:
		return "talk"

	return "attack"
