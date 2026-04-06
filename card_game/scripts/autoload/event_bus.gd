extends Node

# Network events
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)

# State sync (network -> UI)
signal combat_state_updated(state_dict: Dictionary)
signal hand_updated(hand_card_ids: Array)
signal combat_started()
signal combat_over(won: bool)

# Animation events (network -> UI)
signal card_played_visual(peer_id: int, card_id: String, target_index: int)
signal enemy_acted_visual(enemy_index: int, intent_type: int, value: int, target_peer_id: int)

# XP / Leveling
signal xp_gained(amount: int, total: int)
signal player_leveled_up(level: int, rewards: Dictionary)

# Currency
signal currency_changed(currency_type: int, new_balance: int, change_amount: int)

# Player input (UI -> network)
signal local_player_play_card(hand_index: int, target_index: int)
signal local_player_end_turn()

# Voting
signal vote_started(vote_id: String, prompt: String, options: Array)
signal vote_resolved(vote_id: String, result_index: int)
