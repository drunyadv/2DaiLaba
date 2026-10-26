extends Control

const Minimax = preload("res://scripts/minimax.gd")
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
var board_origin: Vector2 = Vector2(48, 210)
var cell_size: float = 80.0
var legend_y: float = 725.0

@onready var status_label: Label = $Info/Margin/Content/Status
@onready var turn_hint: Label = $Info/Margin/Content/TurnHint
@onready var depth_select: OptionButton = $Actions/Depth
@onready var analysis_label: Label = $Info/Margin/Content/Analysis
@onready var new_game_button: Button = $Actions/NewGame
@onready var pop_sound: AudioStreamPlayer = $PopSound


func _ready() -> void:
	board_style.bg_color = Color("29466c")
	board_style.set_corner_radius_all(16)
	for text in ["Глубина: 3", "Глубина: 4", "Глубина: 5"]:
		depth_select.add_item(text)
	depth_select.select(1)
	new_game_button.pressed.connect(start_new_game)
	get_window().size_changed.connect(update_layout)
	update_layout()
	start_new_game()


func update_layout() -> void:
	var pixels: Vector2 = Vector2(get_window().size)
	if pixels.x <= 0 or pixels.y <= 0:
		return
	var portrait: bool = pixels.x < pixels.y
	var width: float = (600.0 if pixels.x > pixels.y * 0.68 else 420.0) if portrait else 1080.0
	var height: float = roundf(width * pixels.y / pixels.x)
	get_window().content_scale_size = Vector2i(int(width), int(height))
	var compact: bool = height < 850.0 if portrait else height < 620.0
	var margin: float = 18.0 if portrait else 32.0
	var info: PanelContainer = $Info
	var actions: HBoxContainer = $Actions
	var info_rect: Rect2
	if portrait:
		cell_size = minf((width - margin * 2) / 7.0, maxf(32.0, (height - 390.0) / 6.0))
		board_origin = Vector2((width - cell_size * 7) / 2.0, 148)
		legend_y = board_origin.y + cell_size * 6 + 24
		place_control(actions, Rect2(margin, legend_y + 24, width - margin * 2, 56))
		var info_y: float = actions.position.y + 72
		info_rect = Rect2(margin, info_y, width - margin * 2, height - info_y - margin)
	else:
		board_origin = Vector2(margin, 128 if compact else 160)
		cell_size = minf(80.0, minf((width * 0.56 - margin - 20) / 7.0,
			(height - board_origin.y - 66) / 6.0))
		legend_y = board_origin.y + cell_size * 6 + 24
		var info_x: float = board_origin.x + cell_size * 7 + 28
		info_rect = Rect2(info_x, board_origin.y - 24,
			width - info_x - margin, height - board_origin.y - margin - 48)
		place_control(actions, Rect2(info_x, height - margin - 56, info_rect.size.x, 56))
	place_control($Title, Rect2(margin, 18 if portrait else 20, width - margin * 2, 44))
	$Title.add_theme_font_size_override("font_size", 32 if portrait or compact else 38)
	place_control($Rules, Rect2(margin, 66 if portrait else 76 if not compact else 62,
		width - margin * 2, 44 if portrait else 40))
	$Rules.add_theme_font_size_override("font_size", 15 if portrait or compact else 17)
	place_control($HumanLegend, Rect2(board_origin.x + 22, legend_y - 13, cell_size * 3, 26))
	place_control($AILegend, Rect2(board_origin.x + cell_size * 3.5 + 22, legend_y - 13,
		cell_size * 3, 26))
	$HumanLegend.add_theme_font_size_override("font_size", 16)
	$AILegend.add_theme_font_size_override("font_size", 16)
	$Controls.visible = not portrait
	$Controls.text = "Клик или клавиши 1-7  /  R - новая игра"
	place_control($Controls, Rect2(margin, height - 27, cell_size * 7, 22))
	$Info/Margin/Content/SectionTitle.visible = not portrait and not compact
	$Info/Margin/Content/Separator.visible = not portrait and not compact
	$Info/Margin/Content/AnalysisTitle.visible = not compact
	turn_hint.visible = not compact
	turn_hint.custom_minimum_size.y = 0
	turn_hint.add_theme_font_size_override("font_size", 15 if portrait else 17)
	status_label.add_theme_font_size_override("font_size", 24 if portrait or compact else 28)
	analysis_label.add_theme_font_size_override("font_size", 14 if portrait else 16)
	analysis_label.max_lines_visible = (2 if portrait and height < 700 else 3) if compact else -1
	$Info/Margin/Content.add_theme_constant_override("separation", 6 if compact else 10)
	for side in ["left", "top", "right", "bottom"]:
		$Info/Margin.add_theme_constant_override("margin_" + side, 12 if portrait or compact else 20)
	place_control(info, info_rect)
	info.set_deferred("size", info_rect.size)
	queue_redraw()


func place_control(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


func play_pop() -> void:
	pop_sound.pitch_scale = randf_range(0.94, 1.06) if randf() < 0.35 else 1.0
	pop_sound.play()


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
	var mouse: Vector2 = point - board_origin
	if mouse.x < 0 or mouse.x >= cell_size * Minimax.COLUMNS:
		return -1
	if mouse.y < -32 or mouse.y >= cell_size * Minimax.ROWS:
		return -1
	return int(mouse.x / cell_size)


func play_human_move(column: int) -> void:
	if not human_turn or game_over:
		return
	var row: int = opponent.drop_piece(board, column, Minimax.HUMAN)
	if row == -1:
		return
	play_pop()
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
	play_pop()
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
	return board_origin + Vector2(column + 0.5, row + 0.5) * cell_size


func _draw() -> void:
	if board.is_empty():
		return
	draw_style_box(board_style, Rect2(board_origin, Vector2(7, 6) * cell_size))
	for column in range(Minimax.COLUMNS):
		var number_color: Color = Color("899bb4")
		if column == hovered_column and board[0][column] == Minimax.EMPTY:
			number_color = HUMAN_COLOR
			draw_rect(Rect2(board_origin + Vector2(column * cell_size, 0),
				Vector2(cell_size, Minimax.ROWS * cell_size)), Color(1, 1, 1, 0.045))
		var number_position: Vector2 = board_origin + Vector2((column + 0.5) * cell_size - 5, -18)
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
			draw_circle(center + Vector2(0, cell_size * 0.025), cell_size * 0.39,
				Color("1b3050"), true, -1, true)
			draw_circle(center, cell_size * 0.36, color, true, -1, true)

	if hovered_column != -1 and board[0][hovered_column] == Minimax.EMPTY:
		for row in range(Minimax.ROWS - 1, -1, -1):
			if board[row][hovered_column] == Minimax.EMPTY:
				draw_circle(cell_center(row, hovered_column), cell_size * 0.36,
					Color(HUMAN_COLOR, 0.3), true, -1, true)
				break
	if last_piece.x != -1:
		draw_circle(cell_center(last_piece.y, last_piece.x), cell_size * 0.05,
			Color(1, 1, 1, 0.85), true, -1, true)
	for cell in winning_cells:
		draw_arc(cell_center(cell.y, cell.x), cell_size * 0.41, 0, TAU, 48, Color("ffffff"), 3, true)
	draw_circle(Vector2(board_origin.x + 7, legend_y), 6, HUMAN_COLOR, true, -1, true)
	draw_circle(Vector2(board_origin.x + cell_size * 3.5 + 7, legend_y), 6, AI_COLOR, true, -1, true)
