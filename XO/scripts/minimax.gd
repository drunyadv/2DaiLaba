extends RefCounted

const ROWS = 6
const COLUMNS = 7
const EMPTY = 0
const HUMAN = 1
const AI = 2
const WIN_SCORE = 1000000
const COLUMN_ORDER = [3, 2, 4, 1, 5, 0, 6]
const DIRECTIONS = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

var nodes_checked: int = 0


func find_best_move(board: Array, depth: int) -> Dictionary:
	nodes_checked = 1
	var columns: Array[int] = get_valid_columns(board)
	if columns.is_empty():
		return {"column": -1, "score": 0, "nodes": nodes_checked, "reason": "Поле заполнено."}

	var human_threats: Array[int] = get_winning_columns(board, HUMAN)
	var safe_columns: Array[int] = []
	for column in columns:
		var row: int = drop_piece(board, column, AI)
		var wins: bool = is_winning_move(board, row, column, AI)
		var safe: bool = wins or get_winning_columns(board, HUMAN).is_empty()
		board[row][column] = EMPTY
		if wins:
			return {
				"column": column, "score": WIN_SCORE + depth - 1, "nodes": nodes_checked,
				"reason": "Завершает линию из четырёх фишек."
			}
		if safe:
			safe_columns.append(column)

	var reason: String = "Выбирает лучшую оценку с учётом ответов соперника."
	if not safe_columns.is_empty():
		if not human_threats.is_empty():
			reason = "Закрывает возможность вашей победы на следующем ходу."
		elif safe_columns.size() < columns.size():
			reason = "Избегает хода, после которого вы могли бы сразу выиграть."
		columns = safe_columns
	else:
		reason = "Любой доступный ход оставляет сопернику немедленную победу."

	var best_column: int = columns[0]
	var best_score: int = -WIN_SCORE * 2
	var alpha: int = -WIN_SCORE * 2
	for column in columns:
		var row: int = drop_piece(board, column, AI)
		var score: int = minimax(board, depth - 1, false, alpha, WIN_SCORE * 2, row, column)
		board[row][column] = EMPTY
		if score > best_score:
			best_score = score
			best_column = column
		alpha = maxi(alpha, best_score)

	return {"column": best_column, "score": best_score, "nodes": nodes_checked, "reason": reason}


func minimax(board: Array, depth: int, maximizing: bool, alpha: int, beta: int,
		last_row: int, last_column: int) -> int:
	nodes_checked += 1
	var previous_player: int = HUMAN if maximizing else AI
	if is_winning_move(board, last_row, last_column, previous_player):
		return WIN_SCORE + depth if previous_player == AI else -WIN_SCORE - depth

	var columns: Array[int] = get_valid_columns(board)
	if columns.is_empty():
		return 0
	if depth == 0:
		return evaluate_board(board)

	var best_score: int = -WIN_SCORE * 2 if maximizing else WIN_SCORE * 2
	var player: int = AI if maximizing else HUMAN
	for column in columns:
		var row: int = drop_piece(board, column, player)
		var score: int = minimax(board, depth - 1, not maximizing, alpha, beta, row, column)
		board[row][column] = EMPTY
		if maximizing:
			best_score = maxi(best_score, score)
			alpha = maxi(alpha, best_score)
		else:
			best_score = mini(best_score, score)
			beta = mini(beta, best_score)
		if alpha >= beta:
			break
	return best_score


func evaluate_board(board: Array) -> int:
	var score: int = 0
	for row in range(ROWS):
		if board[row][3] == AI:
			score += 6
		elif board[row][3] == HUMAN:
			score -= 6

	for row in range(ROWS):
		for column in range(COLUMNS - 3):
			score += evaluate_window(board, row, column, 0, 1)
	for row in range(ROWS - 3):
		for column in range(COLUMNS):
			score += evaluate_window(board, row, column, 1, 0)
	for row in range(ROWS - 3):
		for column in range(COLUMNS - 3):
			score += evaluate_window(board, row, column, 1, 1)
	for row in range(3, ROWS):
		for column in range(COLUMNS - 3):
			score += evaluate_window(board, row, column, -1, 1)
	return score


func evaluate_window(board: Array, row: int, column: int, row_step: int, column_step: int) -> int:
	var own_count: int = 0
	var enemy_count: int = 0
	for offset in range(4):
		var cell: int = board[row + row_step * offset][column + column_step * offset]
		if cell == AI:
			own_count += 1
		elif cell == HUMAN:
			enemy_count += 1
	if own_count > 0 and enemy_count > 0:
		return 0
	if own_count == 3:
		return 100
	if own_count == 2:
		return 10
	if enemy_count == 3:
		return -140
	if enemy_count == 2:
		return -12
	return 0


func get_valid_columns(board: Array) -> Array[int]:
	var columns: Array[int] = []
	for column in COLUMN_ORDER:
		if board[0][column] == EMPTY:
			columns.append(column)
	return columns


func drop_piece(board: Array, column: int, player: int) -> int:
	if column < 0 or column >= COLUMNS:
		return -1
	for row in range(ROWS - 1, -1, -1):
		if board[row][column] == EMPTY:
			board[row][column] = player
			return row
	return -1


func get_winning_columns(board: Array, player: int) -> Array[int]:
	var columns: Array[int] = []
	for column in get_valid_columns(board):
		var row: int = drop_piece(board, column, player)
		if is_winning_move(board, row, column, player):
			columns.append(column)
		board[row][column] = EMPTY
	return columns


func is_winning_move(board: Array, row: int, column: int, player: int) -> bool:
	for direction in DIRECTIONS:
		var count: int = 1
		for side in [-1, 1]:
			for offset in range(1, 4):
				var next_row: int = row + direction.y * offset * side
				var next_column: int = column + direction.x * offset * side
				if next_row < 0 or next_row >= ROWS or next_column < 0 or next_column >= COLUMNS:
					break
				if board[next_row][next_column] != player:
					break
				count += 1
		if count >= 4:
			return true
	return false


func get_winning_cells(board: Array, row: int, column: int, player: int) -> Array[Vector2i]:
	for direction in DIRECTIONS:
		var cells: Array[Vector2i] = [Vector2i(column, row)]
		for side in [-1, 1]:
			var next_cell: Vector2i = Vector2i(column, row) + direction * side
			while next_cell.x >= 0 and next_cell.x < COLUMNS and next_cell.y >= 0 and next_cell.y < ROWS:
				if board[next_cell.y][next_cell.x] != player:
					break
				cells.append(next_cell)
				next_cell += direction * side
		if cells.size() >= 4:
			return cells
	return []
