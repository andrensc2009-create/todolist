import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

//  CONSTANTES DO JOGO
// Tamanho real do pássaro no sprite recortado é 32x27px → escalamos x3
const double kBirdW = 64.0;
const double kBirdH = 54.0;

// Poste recortado: top=57x90, bot=57x39 → escalamos x2.2
const double kPipeW = 100.0;

// Abertura entre poste de cima e de baixo
const double kGapH = 160.0;

const double kGravity = 0.5;
const double kJumpForce = -9.5;
const double kPipeSpeed = 3.0;
const int    kPipesToWin = 5;
const int    kPipeInterval = 100; // frames entre spawns

class FlappyGameDialog extends StatelessWidget {
  final VoidCallback onVitoria;
  const FlappyGameDialog({super.key, required this.onVitoria});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: FlappyGame(onVitoria: onVitoria),
        ),
      ),
    );
  }
}

class FlappyGame extends StatefulWidget {
  final VoidCallback onVitoria;
  const FlappyGame({super.key, required this.onVitoria});

  @override
  State<FlappyGame> createState() => _FlappyGameState();
}

class _FlappyGameState extends State<FlappyGame>
    with SingleTickerProviderStateMixin {

  late AnimationController _ticker;
  final Random _rng = Random();

  // Dimensões reais da área de jogo (preenchidas no LayoutBuilder)
  double _gW = 400;
  double _gH = 600;

  // Posição X fixa do pássaro
  double get _birdX => _gW * 0.22;

  // Estado do pássaro
  double _birdY = 0;       // relativo ao centro da tela
  double _birdVY = 0;
  double _birdAngle = 0;

  // Canos
  final List<_Pipe> _pipes = [];
  int _frameCount = 0;

  // Estado
  bool _started = false;
  bool _dead    = false;
  bool _won     = false;
  int  _score   = 0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_loop);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _loop() {
    if (!_started || _dead || _won) return;
    setState(() {
      _frameCount++;

      // Física
      _birdVY += kGravity;
      _birdY  += _birdVY;
      _birdAngle = (_birdVY / 14).clamp(-0.6, 1.3);

      // Spawn de canos
      if (_frameCount % kPipeInterval == 0) _spawnPipe();

      // Atualiza canos
      final toRemove = <_Pipe>[];
      for (final p in _pipes) {
        p.x -= kPipeSpeed;

        // Passou pelo pássaro?
        if (!p.scored && p.x + kPipeW < _birdX - kBirdW / 2) {
          p.scored = true;
          _score++;
          if (_score >= kPipesToWin) {
            _won = true;
            _ticker.stop();
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.of(context).pop();
                widget.onVitoria();
              }
            });
            return;
          }
        }

        if (p.x + kPipeW < 0) toRemove.add(p);

        if (_hitTest(p)) {
          _dead = true;
          _ticker.stop();
          return;
        }
      }
      _pipes.removeWhere(toRemove.contains);

      // Chão / Teto
      final bTop = _centerY + _birdY - kBirdH / 2;
      final bBot = bTop + kBirdH;
      if (bTop < 0 || bBot > _gH) {
        _dead = true;
        _ticker.stop();
      }
    });
  }

  double get _centerY => _gH / 2;

  void _spawnPipe() {
    // gapCenter entre 25%..75% da altura
    final gc = _gH * 0.25 + _rng.nextDouble() * _gH * 0.50;
    _pipes.add(_Pipe(x: _gW + kPipeW, gapCenter: gc));
  }

  // Hitbox menor que o sprite visual (mais justo)
  bool _hitTest(_Pipe p) {
    const double shrink = 10.0;
    final bL = _birdX  - kBirdW / 2 + shrink;
    final bR = _birdX  + kBirdW / 2 - shrink;
    final bT = _centerY + _birdY - kBirdH / 2 + shrink;
    final bB = _centerY + _birdY + kBirdH / 2 - shrink;

    final pL = p.x + shrink;
    final pR = p.x + kPipeW - shrink;

    // Sem sobreposição horizontal → sem colisão
    if (bR <= pL || bL >= pR) return false;

    final gapTop = p.gapCenter - kGapH / 2;
    final gapBot = p.gapCenter + kGapH / 2;

    return bT < gapTop || bB > gapBot;
  }

  void _tap() {
    if (_dead) { _reset(); return; }
    if (!_started) {
      _started = true;
      _ticker.repeat();
    }
    setState(() => _birdVY = kJumpForce);
  }

  void _reset() {
    setState(() {
      _birdY = 0; _birdVY = 0; _birdAngle = 0;
      _pipes.clear();
      _score = 0; _frameCount = 0;
      _started = false; _dead = false; _won = false;
    });
    _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, ev) {
        if (ev is KeyDownEvent &&
            (ev.logicalKey == LogicalKeyboardKey.space ||
             ev.logicalKey == LogicalKeyboardKey.arrowUp)) {
          _tap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTapDown: (_) => _tap(),
        child: LayoutBuilder(builder: (ctx, bc) {
          _gW = bc.maxWidth;
          _gH = bc.maxHeight;
          return _buildScene();
        }),
      ),
    );
  }

  Widget _buildScene() {
    return Stack(clipBehavior: Clip.hardEdge, children: [
      // ── Fundo ──────────────────────────────────────────────
      Positioned.fill(
        child: Image.asset('assets/Background.png', fit: BoxFit.cover),
      ),

      // ── Canos ──────────────────────────────────────────────
      for (final p in _pipes) ...[
        _pipeTop(p),
        _pipeBottom(p),
      ],

      // ── Pássaro ────────────────────────────────────────────
      Positioned(
        left: _birdX - kBirdW / 2,
        top:  _centerY + _birdY - kBirdH / 2,
        width:  kBirdW,
        height: kBirdH,
        child: Transform.rotate(
          angle: _birdAngle,
          child: Image.asset(
            'assets/bird_crop.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none, // pixel art nítido
          ),
        ),
      ),

      // ── HUD ────────────────────────────────────────────────
      Positioned(
        top: 12, left: 0, right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              '$_score / $kPipesToWin  ⚡',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),

      // ── Tela inicial ───────────────────────────────────────
      if (!_started && !_dead) _overlay(
        emoji: '🐦',
        title: 'IsNotDuolingo',
        subtitle: 'Passe por $kPipesToWin postes para\nadicionar sua tarefa!',
        btnLabel: 'Toque ou Espaço para jogar',
        btnColor: Colors.green.shade600,
      ),

      // ── Game Over ──────────────────────────────────────────
      if (_dead) _overlay(
        emoji: '💥',
        title: 'perdeu!',
        subtitle: 'Você passou $_score poste${_score != 1 ? "s" : ""}...\nTenta de novo!',
        btnLabel: 'Toque para recomeçar',
        btnColor: Colors.red.shade600,
      ),
    ]);
  }

  // Cano de cima: usa pipe_top_crop.png, esticado até a borda superior
  Widget _pipeTop(_Pipe p) {
    final height = p.gapCenter - kGapH / 2;
    if (height <= 0) return const SizedBox.shrink();
    return Positioned(
      left: p.x,
      top: 0,
      width: kPipeW,
      height: height,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationX(3.14159), // vira de cabeça pra baixo
        child: Image.asset(
          'assets/pipe_top_crop.png',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }

  // Cano de baixo: pipe_bot_crop.png, esticado até a borda inferior
  Widget _pipeBottom(_Pipe p) {
    final top = p.gapCenter + kGapH / 2;
    final height = _gH - top;
    if (height <= 0) return const SizedBox.shrink();
    return Positioned(
      left: p.x,
      top: top,
      width: kPipeW,
      height: height,
      child: Image.asset(
        'assets/pipe_bot_crop.png',
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
      ),
    );
  }

  Widget _overlay({
    required String emoji,
    required String title,
    required String subtitle,
    required String btnLabel,
    required Color btnColor,
  }) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(title,
              style: const TextStyle(
                color: Colors.white, fontSize: 28,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 8)],
              ),
            ),
            const SizedBox(height: 10),
            Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70, fontSize: 15,
                shadows: [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
            const SizedBox(height: 28),
            _PulseButton(label: btnLabel, color: btnColor),
          ],
        ),
      ),
    );
  }
}

class _PulseButton extends StatefulWidget {
  final String label;
  final Color color;
  const _PulseButton({required this.label, required this.color});

  @override
  State<_PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<_PulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);
    _scale = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 12)],
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            color: Colors.white, fontSize: 15,
            fontWeight: FontWeight.w700, letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _Pipe {
  double x;
  final double gapCenter;
  bool scored = false;
  _Pipe({required this.x, required this.gapCenter});
}
