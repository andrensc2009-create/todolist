import 'dart:math';
import 'package:flutter/material.dart';
import 'flappy_game.dart';

void main(List<String> args) {
  runApp(const TodoListApp());
}

class TodoListApp extends StatelessWidget {
  const TodoListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TodoList App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const MinhaTelaPrincipal(),
    );
  }
}

class MinhaTelaPrincipal extends StatefulWidget {
  const MinhaTelaPrincipal({super.key});

  @override
  State<MinhaTelaPrincipal> createState() => _MinhaTelaPrincipalState();
}

class _MinhaTelaPrincipalState extends State<MinhaTelaPrincipal>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> tarefas = [];
  final TextEditingController _controleTexto = TextEditingController();

  int _clickCount = 0;          // quantas vezes o + foi clicado
  double _btnX = -1;            // posição X normalizada (-1 = canto padrão)
  double _btnY = -1;            // posição Y normalizada (-1 = canto padrão)
  bool _animating = false;
  late AnimationController _escapeController;
  late Animation<double> _escapeX;
  late Animation<double> _escapeY;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _escapeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _escapeController.dispose();
    _controleTexto.dispose();
    super.dispose();
  }

  void _onFabPressed(BoxConstraints constraints) {
    _clickCount++;

    if (_clickCount == 1 || _clickCount == 2) {
      // Escapar para posição aleatória
      _escaparBotao(constraints);
    } else {
      // Na 3ª vez: abrir o jogo
      _clickCount = 0; // reseta pra trollar de novo depois
      _abrirJogo();
    }
  }

  void _escaparBotao(BoxConstraints constraints) {
    if (_animating) return;

    const double btnSize = 56;
    const double margin = 16;
    final double maxX = constraints.maxWidth - btnSize - margin;
    final double maxY = constraints.maxHeight - btnSize - margin;

    // Posição atual do botão
    double curX = _btnX < 0
        ? constraints.maxWidth - btnSize - margin
        : _btnX * (constraints.maxWidth - btnSize - margin);
    double curY = _btnY < 0
        ? constraints.maxHeight - btnSize - margin
        : _btnY * (constraints.maxHeight - btnSize - margin);

    // Gera nova posição bem diferente da atual
    double newX, newY;
    do {
      newX = margin + _random.nextDouble() * (maxX - margin);
      newY = margin + _random.nextDouble() * (maxY - margin);
    } while ((newX - curX).abs() < 120 || (newY - curY).abs() < 80);

    _escapeX = Tween<double>(
      begin: curX / (constraints.maxWidth - btnSize - margin),
      end: newX / (constraints.maxWidth - btnSize - margin),
    ).animate(CurvedAnimation(parent: _escapeController, curve: Curves.easeOutBack));

    _escapeY = Tween<double>(
      begin: curY / (constraints.maxHeight - btnSize - margin),
      end: newY / (constraints.maxHeight - btnSize - margin),
    ).animate(CurvedAnimation(parent: _escapeController, curve: Curves.easeOutBack));

    _animating = true;
    _escapeController.forward(from: 0).then((_) {
      setState(() {
        _btnX = newX / (constraints.maxWidth - btnSize - margin);
        _btnY = newY / (constraints.maxHeight - btnSize - margin);
        _animating = false;
      });
    });

    // Mostra snackbar de provocação
    final List<String> provocacoes = [
      'Haha',
      'Quase!',
      'Muito lento',
    ];
    final msg = provocacoes[_random.nextInt(provocacoes.length)];
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  void _abrirJogo() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => FlappyGameDialog(
        onVitoria: () {
          // Após vencer o jogo, abre o formulário de tarefa
          Future.delayed(const Duration(milliseconds: 100), abrirJanelaCadastro);
        },
      ),
    );
  }

  void abrirJanelaCadastro() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Text('!'),
              Text('Nova Tarefa'),
            ],
          ),
          content: TextField(
            controller: _controleTexto,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Digite o nome da tarefa...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_controleTexto.text.isNotEmpty) {
                  setState(() {
                    tarefas.add({
                      'titulo': _controleTexto.text,
                      'concluida': false,
                    });
                  });
                  _controleTexto.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TodoList App'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.yellow,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // ---- Lista de tarefas ----
              tarefas.isEmpty
                  ? const Center(child: Text('Nenhuma tarefa por enquanto...'))
                  : ListView.builder(
                      itemCount: tarefas.length,
                      itemBuilder: (context, index) {
                        final bool estaConcluida = tarefas[index]['concluida'];
                        return ListTile(
                          leading: Icon(
                            estaConcluida
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: Colors.green,
                          ),
                          title: Text(
                            tarefas[index]['titulo'],
                            style: TextStyle(
                              decoration: estaConcluida
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: estaConcluida ? Colors.grey : Colors.black,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() => tarefas.removeAt(index));
                            },
                          ),
                          onTap: () {
                            setState(() {
                              tarefas[index]['concluida'] =
                                  !tarefas[index]['concluida'];
                            });
                          },
                        );
                      },
                    ),

              // ---- Botão flutuante que escapa ----
              AnimatedBuilder(
                animation: _escapeController,
                builder: (context, child) {
                  const double btnSize = 56;
                  const double margin = 16;
                  double x, y;

                  if (_btnX < 0) {
                    // Posição padrão (canto inferior direito)
                    x = constraints.maxWidth - btnSize - margin;
                    y = constraints.maxHeight - btnSize - margin;
                  } else if (_animating) {
                    x = _escapeX.value * (constraints.maxWidth - btnSize - margin);
                    y = _escapeY.value * (constraints.maxHeight - btnSize - margin);
                  } else {
                    x = _btnX * (constraints.maxWidth - btnSize - margin);
                    y = _btnY * (constraints.maxHeight - btnSize - margin);
                  }

                  return Positioned(
                    left: x,
                    top: y,
                    child: _TrollFab(
                      clickCount: _clickCount,
                      onPressed: () => _onFabPressed(constraints),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrollFab extends StatelessWidget {
  final int clickCount;
  final VoidCallback onPressed;

  const _TrollFab({required this.clickCount, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // Muda a cor conforme cliques: azul → laranja → vermelho → azul de novo
    final List<Color> cores = [
      Colors.blue,
      Colors.orange,
      Colors.red,
    ];
    final color = cores[clickCount % cores.length];

    final List<String> tooltips = [
      'Adicionar tarefa',
      'Quase lá... (2/3)',
      'Última chance!',
    ];

    return Tooltip(
      message: tooltips[clickCount % tooltips.length],
      child: FloatingActionButton(
        heroTag: 'troll_fab',
        onPressed: onPressed,
        backgroundColor: color,
        child: const Icon(Icons.add),
      ),
    );
  }
}
