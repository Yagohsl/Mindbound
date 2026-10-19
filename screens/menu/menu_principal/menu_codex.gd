extends Control

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var livro_sprite: Sprite2D = $LivroSprite
@onready var conteudo_livro: Control = $ConteudoLivro

# Elementos da Página Esquerda (Boss)
@onready var boss_sprite: Sprite2D = $ConteudoLivro/PaginaEsquerda/VBoxContainer/BossSpriteContainer/BossSprite
@onready var boss_nome_label: Label = $ConteudoLivro/PaginaEsquerda/VBoxContainer/BossNomeLabel
@onready var boss_subtitulo_label: Label = $ConteudoLivro/PaginaEsquerda/VBoxContainer/BossSubtituloLabel
@onready var boss_tag_label: Label = $ConteudoLivro/PaginaEsquerda/VBoxContainer/BossTagLabel
@onready var btn_lutar: Button = $ConteudoLivro/PaginaEsquerda/VBoxContainer/BtnLutar
@onready var boss_resumo_label: RichTextLabel = $ConteudoLivro/PaginaEsquerda/VBoxContainer/BossResumoLabel

# Elementos da Página Direita (Psicoeducação & Sintomas)
@onready var titulo_analise_label: Label = $ConteudoLivro/PaginaDireita/TituloAnaliseLabel
@onready var scroll_container: ScrollContainer = $ConteudoLivro/PaginaDireita/ScrollContainer
@onready var texto_psicoeducativo: RichTextLabel = $ConteudoLivro/PaginaDireita/ScrollContainer/TextoPsicoeducativo

# Controles de Navegação (Embaixo)
@onready var btn_anterior: Button = $NavegacaoInferior/HBoxContainer/BtnAnterior
@onready var btn_proximo: Button = $NavegacaoInferior/HBoxContainer/BtnProximo
@onready var indicador_pagina: Label = $NavegacaoInferior/HBoxContainer/IndicadorPagina
@onready var btn_voltar: Button = $NavegacaoInferior/BtnVoltar

# Estado de navegação e animação do Boss
var current_boss_index: int = 0
var current_frame_index: int = 0
var frame_timer: float = 0.0
var carregando_pagina: bool = false

# Base de Dados Psicoeducativa dos Bosses
var bosses_data: Array = [
	{
		"nome": "ANSIEDADE",
		"subtitulo": "Transtorno de Ansiedade Generalizada (TAG)",
		"tag": "HIPERVIGILÂNCIA",
		"arena_scene": "res://screens/arenas/arena_ansiedade/arena_ans.tscn",
		"resumo": "[shake rate=5.0 level=1 connected=1]\"Um alarme perpétuo disparando sem incêndio, aprisionando a mente na iminência do pior cenário.\"[/shake]",
		"texture_path": "res://assets/images/game/fighters/ansiedade.png",
		"hframes": 4,
		"vframes": 6,
		"idle_frames": [0, 1, 2, 3],
		"frame_duration": 0.15,
		"sprite_scale": Vector2(2.6, 2.6),
		"sprite_offset": Vector2(0, 0),
		"sintomas_html": "[color=#1c1815]MECANISMO NEUROBIOLÓGICO[/color]\nHiperativação disfuncional da amígdala cerebral e do eixo HPA (hipotálamo-hipófise-adrenal). O cérebro avalia estímulos neutros cotidianos como ameaças críticas à sobrevivência, disparando torrentes involuntárias de cortisol e adrenalina.\n\n[color=#1c1815]MANIFESTAÇÕES FISIOLÓGICAS[/color]\n• Taquicardia, palpitações e aperto torácico.\n• Respiração rápida, curta e sensação de sufocamento.\n• Tensão muscular sustentada e cefaleia tensional.\n• Sudorese, tremores periféricos e náusea somática.\n\n[color=#1c1815]MANIFESTAÇÕES COGNITIVAS[/color]\n• Pensamento catastrófico em cascata (\"e se der tudo errado?\").\n• Hipervigilância exaustiva e escaneamento constante de riscos.\n• Ruminação mental intrusiva e paralisia decisória (\"freeze\").\n\n[color=#1c1815]COMPREENSÃO PSICOEDUCATIVA[/color]\nA ansiedade não representa fragilidade moral, mas uma resposta protetiva biológica desregulada. O manejo clínico baseia-se em respiração diafragmática (ativação vagal/parassimpática), validação afetiva e reestruturação cognitiva para ancorar a mente na realidade presente."
	},
	{
		"nome": "DEPRESSÃO",
		"subtitulo": "Transtorno Depressivo Maior (TDM)",
		"tag": "ANERGIA & ANEDONIA",
		"arena_scene": "res://screens/arenas/arena_depressao/arena_dep.tscn",
		"resumo": "\"Um peso implacável que retira o brilho de cada instante, transformando o simples acordar em um fardo.\"",
		"texture_path": "res://assets/images/game/fighters/depressao.png",
		"hframes": 5,
		"vframes": 7,
		"idle_frames": [0, 1, 2, 3],
		"frame_duration": 0.35,
		"sprite_scale": Vector2(2.0, 2.0),
		"sprite_offset": Vector2(0, 0),
		"sintomas_html": "[color=#1c1815]MECANISMO NEUROBIOLÓGICO[/color]\nHipoativação das vias dopaminérgicas e serotoninérgicas mesolímbicas associada a disfunções no córtex pré-frontal ventromedial. Há redução na neuroplasticidade e colapso no sistema endógeno de recompensa e motivação.\n\n[color=#1c1815]MANIFESTAÇÕES NUCLEARES[/color]\n• Anedonia profunda: Perda quase total do prazer e interesse em atividades antes significativas.\n• Anergia e Fadiga crônica: Sensação de chumbo nos membros e exaustão física intransponível.\n• Alterações severas no padrão de sono e apetite.\n\n[color=#1c1815]MANIFESTAÇÕES COGNITIVAS[/color]\n• Lentificação do processamento psicomotor e névoa mental.\n• Ideações desproporcionais de culpa, inutilidade e desvalia.\n• Sensação de vazio existencial imenso e isolamento voluntário.\n\n[color=#1c1815]COMPREENSÃO PSICOEDUCATIVA[/color]\nDepressão não é tristeza vulgar nem carência de força de vontade; é uma desregulação química e funcional comprovada. A recuperação envolve pequenas ativações comportamentais graduais, rede de apoio empática e intervenções terapêuticas especializadas."
	},
	{
		"nome": "TDAH",
		"subtitulo": "Déficit de Atenção com Hiperatividade",
		"tag": "DISFUNÇÃO EXECUTIVA",
		"arena_scene": "res://screens/arenas/arena_tdah/arena_tdah.tscn",
		"resumo": "\"Dez pensamentos paralelos disputando prioridade, buscando dopamina enquanto os prazos se esvaem.\"",
		"texture_path": "res://assets/images/game/fighters/TDAH.png",
		"hframes": 6,
		"vframes": 2,
		"idle_frames": [0],
		"frame_duration": 0.12,
		"sprite_scale": Vector2(2.6, 2.6),
		"sprite_offset": Vector2(0, 0),
		"sintomas_html": "[color=#1c1815]MECANISMO NEUROBIOLÓGICO[/color]\nDeficiência na sinalização e recaptação desregulada de dopamina e noradrenalina nos circuitos frontoestriatais. Afeta diretamente as Funções Executivas cerebrais (controle inibitório, memória operacional e foco seletivo).\n\n[color=#1c1815]O PARADOXO DA ATENÇÃO[/color]\n• Oscilação Atencional: Dificuldade em reter o foco em tarefas burocráticas ou com recompensa a longo prazo.\n• Hiperfoco Seletivo: Estado de imersão total e concentração extraordinária diante de atividades de alto interesse.\n\n[color=#1c1815]MANIFESTAÇÕES COMPORTAMENTAIS[/color]\n• Inquietação psicomotora contínua (física ou fluxo mental).\n• Cegueira temporal (*time blindness*) e procrastinação por sobrecarga.\n• Impulsividade na fala e no início desordenado de projetos.\n\n[color=#1c1815]COMPREENSÃO PSICOEDUCATIVA[/color]\nO TDAH não se caracteriza por escassez de atenção, mas sim por dificuldade na [i]regulação[/i] atencional. Estratégias ambientais externas, fragmentação de metas em micro-etapas e aceitação desbloqueiam alto potencial criativo e inovador."
	},
	{
		"nome": "BURNOUT",
		"subtitulo": "Síndrome do Esgotamento Profissional",
		"tag": "COLAPSO POR\nESTRESSE CRÔNICO",
		"arena_scene": "res://screens/menu/menu_principal/menu_principal.tscn",
		"resumo": "\"A chama que insistiu em arder sem descanso até consumir o próprio combustível, restando fuligem.\"",
		"texture_path": "res://assets/images/game/fighters/TDAH.png",
		"hframes": 6,
		"vframes": 2,
		"idle_frames": [1],
		"frame_duration": 0.18,
		"sprite_scale": Vector2(1.7, 1.7),
		"sprite_offset": Vector2(0, 0),
		"sintomas_html": "[color=#1c1815]MECANISMO NEUROBIOLÓGICO[/color]\nEsgotamento da tolerância alostática por exposição contínua a demandas excessivas sem período de recuperação biológica. O excesso crônico de cortisol satura sinapses neuronais, provocando colapso sistêmico do organismo.\n\n[color=#1c1815]A TRÍADE DIAGNÓSTICA (CID-11)[/color]\n• Exaustão Emocional Extrema: Esgotamento absoluto da energia vital; sensação de estar queimado até as cinzas.\n• Despersonalização / Cinismo: Postura de indiferença, apatia ou ceticismo defensivo para mitigar a dor da sobrecarga.\n• Ineficácia Percebida: Sensação de incompetência crônica, névoa mental densa (*brain fog*) e desesperança.\n\n[color=#1c1815]COMPREENSÃO PSICOEDUCATIVA[/color]\nO Burnout é o resultado de estruturas de cobrança desmedidas e da negligência reiterada dos próprios limites biológicos. A recuperação real não depende de 'força de vontade', mas da imposição firme de limites, repouso autêntico e reestruturação do estilo de vida."
	}
]

func _ready() -> void:
	# Configura conexões dos botões
	if btn_anterior and not btn_anterior.pressed.is_connected(_on_btn_anterior_pressed):
		btn_anterior.pressed.connect(_on_btn_anterior_pressed)
	if btn_proximo and not btn_proximo.pressed.is_connected(_on_btn_proximo_pressed):
		btn_proximo.pressed.connect(_on_btn_proximo_pressed)
	if btn_voltar and not btn_voltar.pressed.is_connected(_on_btn_voltar_pressed):
		btn_voltar.pressed.connect(_on_btn_voltar_pressed)
	if btn_lutar and not btn_lutar.pressed.is_connected(_on_btn_lutar_pressed):
		btn_lutar.pressed.connect(_on_btn_lutar_pressed)
		
	# Abre o caderno com animação se disponível
	if anim_player and anim_player.has_animation("abrir_caderno"):
		anim_player.play("abrir_caderno")
		await anim_player.animation_finished
	elif livro_sprite:
		livro_sprite.frame = 3 # Garante o livro aberto
		
	exibir_boss(0, false)

func _process(delta: float) -> void:
	# Anima o sprite idle do boss atual
	if current_boss_index >= 0 and current_boss_index < bosses_data.size():
		var data = bosses_data[current_boss_index]
		var idle_frames: Array = data.get("idle_frames", [0])
		if idle_frames.size() > 0 and boss_sprite:
			frame_timer += delta
			var dur: float = data.get("frame_duration", 0.2)
			if frame_timer >= dur:
				frame_timer -= dur
				current_frame_index = (current_frame_index + 1) % idle_frames.size()
				boss_sprite.frame = idle_frames[current_frame_index]

func exibir_boss(index: int, animar_transicao: bool = false) -> void:
	if index < 0 or index >= bosses_data.size():
		return
		
	current_boss_index = index
	current_frame_index = 0
	frame_timer = 0.0
	
	var data = bosses_data[current_boss_index]
	
	if animar_transicao and conteudo_livro:
		carregando_pagina = true
		var tween = create_tween()
		tween.tween_property(conteudo_livro, "modulate:a", 0.0, 0.12)
		await tween.finished
		_atualizar_interface(data)
		var tween_in = create_tween()
		tween_in.tween_property(conteudo_livro, "modulate:a", 1.0, 0.15)
		await tween_in.finished
		carregando_pagina = false
	else:
		if conteudo_livro:
			conteudo_livro.modulate.a = 1.0
		_atualizar_interface(data)

func virar_pagina(novo_indice: int, para_frente: bool) -> void:
	if novo_indice < 0 or novo_indice >= bosses_data.size():
		return
	if carregando_pagina:
		return
		
	carregando_pagina = true
	var anim_nome = "virar_pagina_proximo" if para_frente else "virar_pagina_anterior"
	
	# Dispara a animação no sprite do Livro
	if anim_player and anim_player.has_animation(anim_nome):
		anim_player.play(anim_nome)
	elif anim_player and anim_player.has_animation("virar_pagina_proximo"):
		if para_frente:
			anim_player.play("virar_pagina_proximo")
		else:
			anim_player.play_backwards("virar_pagina_proximo")
	
	# Desvanece o conteúdo da página durante a elevação da folha
	if conteudo_livro:
		var tween_out = create_tween()
		tween_out.tween_property(conteudo_livro, "modulate:a", 0.0, 0.12)
		await tween_out.finished
	else:
		await get_tree().create_timer(0.12).timeout
		
	# Atualiza os dados do novo boss no meio da virada
	current_boss_index = novo_indice
	current_frame_index = 0
	frame_timer = 0.0
	_atualizar_interface(bosses_data[current_boss_index])
	
	# Aguarda a folha assentar
	await get_tree().create_timer(0.12).timeout
	
	# Revela o conteúdo da nova página suavemente
	if conteudo_livro:
		var tween_in = create_tween()
		tween_in.tween_property(conteudo_livro, "modulate:a", 1.0, 0.14)
		await tween_in.finished
		
	if anim_player and anim_player.is_playing():
		await anim_player.animation_finished
		
	if livro_sprite:
		livro_sprite.frame = 3
		
	carregando_pagina = false

func _atualizar_interface(data: Dictionary) -> void:
	# Atualiza Indicador de Página
	if indicador_pagina:
		indicador_pagina.text = "BOSS %d / %d" % [current_boss_index + 1, bosses_data.size()]
		
	# Atualiza Informações da Página Esquerda
	if boss_nome_label:
		boss_nome_label.text = data.get("nome", "")
	if boss_subtitulo_label:
		boss_subtitulo_label.text = data.get("subtitulo", "")
	if boss_tag_label:
		boss_tag_label.text = data.get("tag", "")
	if boss_resumo_label:
		boss_resumo_label.text = data.get("resumo", "")
		
	# Configura e carrega o Sprite do Boss
	if boss_sprite:
		var tex_path = data.get("texture_path", "")
		if ResourceLoader.exists(tex_path):
			boss_sprite.texture = load(tex_path)
		boss_sprite.hframes = data.get("hframes", 1)
		boss_sprite.vframes = data.get("vframes", 1)
		boss_sprite.scale = data.get("sprite_scale", Vector2(2.5, 2.5))
		boss_sprite.offset = data.get("sprite_offset", Vector2.ZERO)
		var idle_frames: Array = data.get("idle_frames", [0])
		boss_sprite.frame = idle_frames[0] if idle_frames.size() > 0 else 0
		
	# Atualiza Informações da Página Direita
	if texto_psicoeducativo:
		texto_psicoeducativo.text = data.get("sintomas_html", "")
		
	# Reseta o scroll da página direita para o topo
	if scroll_container:
		scroll_container.scroll_vertical = 0

func _on_btn_lutar_pressed() -> void:
	if current_boss_index >= 0 and current_boss_index < bosses_data.size():
		var data = bosses_data[current_boss_index]
		var arena_path: String = data.get("arena_scene", "")
		if arena_path != "" and ResourceLoader.exists(arena_path):
			get_tree().change_scene_to_file(arena_path)

func _on_btn_proximo_pressed() -> void:
	if carregando_pagina:
		return
	var prox = (current_boss_index + 1) % bosses_data.size()
	virar_pagina(prox, true)

func _on_btn_anterior_pressed() -> void:
	if carregando_pagina:
		return
	var ant = (current_boss_index - 1 + bosses_data.size()) % bosses_data.size()
	virar_pagina(ant, false)

func _on_btn_voltar_pressed() -> void:
	get_tree().change_scene_to_file("res://screens/menu/menu_principal/menu_principal.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_btn_voltar_pressed()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_on_btn_proximo_pressed()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_on_btn_anterior_pressed()
