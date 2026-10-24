extends Control

const Minimax = preload("res://scripts/minimax.gd")
const BOARD_ORIGIN = Vector2(48, 210)
const CELL_SIZE = 80.0
const HUMAN_COLOR = Color("ef7373")
const AI_COLOR = Color("f3c969")

var opponent = Minimax.new()
var board: Array = []
var human_turn: bool = true
var game_over: bool = false
var round_number: int = 0
var hovered_column: int = -1
var last_piece: Vector2i = Vector2i(-1, -1)
var winning_cells: Array[Vector2i] = []
var board_style: StyleBoxFlat = StyleBoxFlat.new()

@onready var status_label: Label = $Info/Margin/Content/Status
@onready var turn_hint: Label = $Info/Margin/Content/TurnHint
@onready var depth_select: OptionButton = $Info/Margin/Content/Depth
@onready var analysis_label: Label = $Info/Margin/Content/Analysis
@onready var new_game_button: Button = $NewGame


func _ready() -> void:
	board_style.bg_color = Color("29466c")
	board_style.set_corner_radius_all(16)
	for text in ["3 полухода", "4 полухода", "5 полуходов"]:
		depth_select.add_item(text)
	depth_select.select(1)
	new_game_button.pressed.connect(start_new_game)
	start_new_game()


func start_new_game() -> void:
	round_number += 1
	board.clear()
	for row in range(Minimax.ROWS):
		var cells: Array[int] = []
		cells.resize(Minimax.COLUMNS)
		cells.fill(Minimax.EMPTY)
		board.append(cells)
	human_turn = true
	game_over = false
	last_piece = Vector2i(-1, -1)
	winning_cells.clear()
	depth_select.disabled = false
	status_label.text = "Ваш ход"
	status_label.modulate = HUMAN_COLOR
	turn_hint.text = "Выберите столбец, чтобы опустить красную фишку. Вы ходите первым."
	analysis_label.text = "Сделайте первый ход.\nЗдесь появится результат поиска."
	refresh_board()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var column: int = column_at_position(get_local_mouse_position()) if human_turn and not game_over else -1
		if column != hovered_column:
			hovered_column = column
			queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var column: int = column_at_position(event.position)
		if column != -1:
			play_human_move(column)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			start_new_game()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
			play_human_move(event.keycode - KEY_1)


func column_at_position(point: Vector2) -> int:
	var mouse: Vector2 = point - BOARD_ORIGIN
	if mouse.x < 0 or mouse.x >= CELL_SIZE * Minimax.COLUMNS:
		return -1
	if mouse.y < -40 or mouse.y >= CELL_SIZE * Minimax.ROWS:
		return -1
	return int(mouse.x / CELL_SIZE)


func play_human_move(column: int) -> void:
	if not human_turn or game_over:
		return
	var row: int = opponent.drop_piece(board, column, Minimax.HUMAN)
	if row == -1:
		return
	last_piece = Vector2i(column, row)
	if finish_if_needed(row, column, Minimax.HUMAN):
		return

	human_turn = false
	depth_select.disabled = true
	status_label.text = "ИИ думает..."
	status_label.modulate = AI_COLOR
	turn_hint.text = "Перебирает ходы и возможные ответы."
	refresh_board()
	var current_round: int = round_number
	await get_tree().create_timer(0.15).timeout
	if current_round != round_number or game_over:
		return

	var depth: int = depth_select.selected + 3
	var result: Dictionary = opponent.find_best_move(board, depth)
	var ai_column: int = result["column"]
	if ai_column == -1:
		finish_draw()
		return
	var ai_row: int = opponent.drop_piece(board, ai_column, Minimax.AI)
	last_piece = Vector2i(ai_column, ai_row)
	analysis_label.text = "Столбец: %d  |  Глубина: %d\nОценка: %d\nУзлов Minimax: %d\n\n%s" % [
		ai_column + 1, depth, result["score"], result["nodes"], result["reason"]
	]
	depth_select.disabled = false
	if finish_if_needed(ai_row, ai_column, Minimax.AI):
		return
	human_turn = true
	status_label.text = "Ваш ход"
	status_label.modulate = HUMAN_COLOR
	turn_hint.text = "Выберите свободный столбец. Точка отмечает последнюю фишку."
	refresh_board()


func finish_if_needed(row: int, column: int, player: int) -> bool:
	if opponent.is_winning_move(board, row, column, player):
		game_over = true
		human_turn = false
		winning_cells = opponent.get_winning_cells(board, row, column, player)
		status_label.text = "Вы победили!" if player == Minimax.HUMAN else "Победа ИИ"
		status_label.modulate = HUMAN_COLOR if player == Minimax.HUMAN else AI_COLOR
		turn_hint.text = "Четыре фишки в ряд. Нажмите \"Новая игра\", чтобы сыграть ещё раз."
		refresh_board()
		return true
	if opponent.get_valid_columns(board).is_empty():
		finish_draw()
		return true
	return false


func finish_draw() -> void:
	game_over = true
	human_turn = false
	depth_select.disabled = false
	status_label.text = "Ничья"
	status_label.modulate = Color("e5edf9")
	turn_hint.text = "Поле заполнено, четырёх фишек в ряд нет. Можно начать новую игру."
	refresh_board()


func refresh_board() -> void:
	hovered_column = column_at_position(get_local_mouse_position()) if human_turn and not game_over else -1
	queue_redraw()


func cell_center(row: int, column: int) -> Vector2:
	return BOARD_ORIGIN + Vector2(column + 0.5, row + 0.5) * CELL_SIZE


func _draw() -> void:
	if board.is_empty():
		return
	draw_style_box(board_style, Rect2(BOARD_ORIGIN, Vector2(7, 6) * CELL_SIZE))
	for column in range(Minimax.COLUMNS):
		var number_color: Color = Color("899bb4")
		if column == hovered_column and board[0][column] == Minimax.EMPTY:
			number_color = HUMAN_COLOR
			draw_rect(Rect2(BOARD_ORIGIN + Vector2(column * CELL_SIZE, 0),
				Vector2(CELL_SIZE, Minimax.ROWS * CELL_SIZE)), Color(1, 1, 1, 0.045))
		var number_position: Vector2 = BOARD_ORIGIN + Vector2((column + 0.5) * CELL_SIZE - 5, -20)
		draw_string(ThemeDB.fallback_font, number_position, str(column + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, number_color)

	for row in range(Minimax.ROWS):
		for column in range(Minimax.COLUMNS):
			var center: Vector2 = cell_center(row, column)
			var color: Color = Color("111d2f")
			if board[row][column] == Minimax.HUMAN:
				color = HUMAN_COLOR
			elif board[row][column] == Minimax.AI:
				color = AI_COLOR
			draw_circle(center + Vector2(0, 2), 31, Color("1b3050"), true, -1, true)
			draw_circle(center, 29, color, true, -1, true)

	if hovered_column != -1 and board[0][hovered_column] == Minimax.EMPTY:
		for row in range(Minimax.ROWS - 1, -1, -1):
			if board[row][hovered_column] == Minimax.EMPTY:
				draw_circle(cell_center(row, hovered_column), 29, Color(HUMAN_COLOR, 0.3), true, -1, true)
				break
	if last_piece.x != -1:
		draw_circle(cell_center(last_piece.y, last_piece.x), 4, Color(1, 1, 1, 0.85), true, -1, true)
	for cell in winning_cells:
		draw_arc(cell_center(cell.y, cell.x), 33, 0, TAU, 48, Color("ffffff"), 3, true)
	draw_circle(Vector2(60, 725), 7, HUMAN_COLOR, true, -1, true)
	draw_circle(Vector2(248, 725), 7, AI_COLOR, true, -1, true)
