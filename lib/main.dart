import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const RealPangGameApp());
}

// 💡 누락되었던 메인 앱 클래스 복구!
class RealPangGameApp extends StatelessWidget {
  const RealPangGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "픽셀 팡팡!",
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const GameLoader(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- 이미지 리소스 로더 ---
class GameImages {
  static ui.Image? doImage;
  static ui.Image? soImage;
  static ui.Image? c1Image;
  static ui.Image? c2Image;

  static ui.Image? b1Image;
  static ui.Image? b2Image;
  static ui.Image? b3Image;
  static ui.Image? b4Image;

  static ui.Image? bodyImage;

  static Future<void> load() async {
    try {
      doImage = await _loadImageFromAsset('assets/do.png');
      soImage = await _loadImageFromAsset('assets/so.png');
      c1Image = await _loadImageFromAsset('assets/c1.png');
      c2Image = await _loadImageFromAsset('assets/c2.png');

      b1Image = await _loadImageFromAsset('assets/do.png');
      b2Image = await _loadImageFromAsset('assets/so.png');
      b3Image = await _loadImageFromAsset('assets/c1.png');
      b4Image = await _loadImageFromAsset('assets/c2.png');

      bodyImage = await _loadImageFromAsset('assets/body.png');
    } catch (e) {
      debugPrint("이미지 로딩 실패: $e");
    }
  }

  static Future<ui.Image> _loadImageFromAsset(String path) async {
    final ByteData data = await rootBundle.load(path);
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(data.buffer.asUint8List(), (ui.Image img) {
      return completer.complete(img);
    });
    return completer.future;
  }
}

class GameLoader extends StatefulWidget {
  const GameLoader({super.key});
  @override
  State<GameLoader> createState() => _GameLoaderState();
}

class _GameLoaderState extends State<GameLoader> {
  bool _imagesLoaded = false;

  @override
  void initState() {
    super.initState();
    GameImages.load().then((_) {
      setState(() => _imagesLoaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_imagesLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 20),
            Text("리소스를 불러오는 중...", style: TextStyle(color: Colors.white)),
          ],
        )),
      );
    }
    return const GameScreen();
  }
}

// --- 게임 모델 클래스 ---

class Ball {
  double x, y;
  double vx, vy;
  int sizeLevel;
  int hp;
  int hitTimer = 0;
  late double radius;
  late Color baseColor;
  double bounceSpeedMult;

  bool isBoss = false;
  bool isClone = false;
  int frameCount = 0;

  Ball({required this.x, required this.y, required this.vx, required this.vy, required this.sizeLevel, required this.hp, this.bounceSpeedMult = 1.0}) {
    radius = (sizeLevel == 5) ? 55.0 : (sizeLevel == 4) ? 45.0 : (sizeLevel == 3) ? 35.0 : (sizeLevel == 2) ? 22.0 : 12.0;
    baseColor = (sizeLevel == 5) ? Colors.red : (sizeLevel == 4) ? Colors.deepOrange : (sizeLevel == 3) ? Colors.blue : (sizeLevel == 2) ? Colors.green : Colors.purple;
  }

  void update(double screenWidth, double screenHeight, double gravity, double speedMult) {
    double currentGravity = gravity * bounceSpeedMult * speedMult;
    vy += currentGravity;

    x += (vx * speedMult);
    y += (vy * speedMult);

    if (x - radius < 0) { x = radius; vx = -vx; }
    else if (x + radius > screenWidth) { x = screenWidth - radius; vx = -vx; }

    double groundY = screenHeight - 60;
    if (y + radius > groundY) {
      y = groundY - radius;
      double baseBounce = (sizeLevel == 5) ? -10.5 : (sizeLevel == 4) ? -9.5 : (sizeLevel == 3) ? -8.5 : (sizeLevel == 2) ? -7.5 : -6.0;
      vy = baseBounce * bounceSpeedMult;
    }

    if (hitTimer > 0) hitTimer--;
  }
}

class Arrow {
  double x, y, vx, vy;
  int bouncesLeft;
  List<Offset> joints;
  bool active = true;

  Arrow({required this.x, required this.y, required this.vx, required this.vy, required this.bouncesLeft, required this.joints});

  void update(double screenWidth, double groundY) {
    y -= vy; x += vx;

    if (x < 0 || x > screenWidth) {
      if (bouncesLeft > 0) {
        vx = -vx; bouncesLeft--; joints.add(Offset(x < 0 ? 0 : screenWidth, y));
      } else { active = false; }
      x = x.clamp(0, screenWidth);
    }

    if (y < 0) {
      y = 0;
      if (bouncesLeft > 0) { vy = -vy; bouncesLeft--; joints.add(Offset(x, y)); }
      else { active = false; }
    }

    if (y > groundY) active = false;
  }
}

class GameItem {
  double x, y;
  int type;
  double vy = 3.0;
  bool active = true;
  int groundTimer = 0;

  GameItem({required this.x, required this.y, required this.type});

  void update(double groundY) {
    if (y < groundY - 12) { y += vy; }
    else {
      y = groundY - 12;
      groundTimer++;
      if (groundTimer > 300) active = false;
    }
  }
}

class Missile {
  double x, y;
  double vy = 3.0;
  bool active = true;

  Missile({required this.x, required this.y});

  void update(double groundY) {
    y += vy;
    if (y > groundY) active = false;
  }
}

// --- 메인 게임 화면 ---

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // 💡 [테스트 설정] 배포 시 false로 바꾸면 테스트 버튼이 사라집니다.
  final bool isTestMode = true;

  // 💡 [속도 조절 마스터 변수] 1.0이 기본 속도, 0.5면 50% 느려짐, 2.0이면 2배 빨라짐
  final double globalBallSpeed = 0.6;

  late Size screenSize;
  double playerX = 0;

  final double playerWidth = 30;
  final double playerHeight = 53.0;

  final double basePlayerSpeed = 6.0;
  int playerSpeedLevel = 0;
  int maxActiveArrows = 1;
  int multiShotLevel = 0;
  int arrowBounces = 0;
  double arrowSpeed = 8.0;
  int fireCooldown = 0;

  ui.Image? selectedPlayerImage;
  ui.Image? selectedBossImage;

  int controlMode = 0;
  int selectionState = 0;

  List<Arrow> activeArrows = [];
  List<GameItem> items = [];
  List<Ball> balls = [];
  List<Missile> missiles = [];

  int score = 0;
  int currentRound = 1;
  int bossDefeatCount = 0;

  bool isGameOver = false;
  bool isGameClear = false;
  bool isPlaying = false;
  bool isRoundTransition = false;
  bool showDefeatedBoss = false;

  int _flashTimer = 0;

  Timer? gameTimer;
  final double gravity = 0.12;
  final Random random = Random();
  final FocusNode _focusNode = FocusNode();

  bool isLeftPressed = false;
  bool isRightPressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    screenSize = MediaQuery.of(context).size;
    if (playerX == 0) playerX = screenSize.width / 2;
  }

  void _onPlayerSelected(ui.Image? image) {
    setState(() { selectedPlayerImage = image; selectionState = 1; });
  }

  void _onBossSelected(ui.Image? image) {
    setState(() { selectedBossImage = image; selectionState = 2; });
  }

  void _onModeSelected(int mode) {
    setState(() {
      controlMode = mode;
      selectionState = 3;
      _startFullGame();
    });
  }

  void _jumpTo(int round, {bool clear = false}) {
    setState(() {
      if (clear) {
        score = 0;
        isGameClear = true;
        selectionState = 3;
      } else {
        score = 0;
        currentRound = round;
        if (round <= 3) bossDefeatCount = 0;
        else if (round <= 6) bossDefeatCount = 1;
        else if (round <= 9) bossDefeatCount = 2;
        else bossDefeatCount = 3;

        selectionState = 3;
        _startRound();
      }
    });
  }

  void _startFullGame() {
    score = 0;
    currentRound = 1;
    bossDefeatCount = 0;
    isGameOver = false;
    isGameClear = false;
    playerSpeedLevel = 0;
    maxActiveArrows = 1;
    multiShotLevel = 0;
    arrowBounces = 0;
    _flashTimer = 0;
    _startRound();
  }

  void _startRound() {
    activeArrows.clear();
    items.clear();
    missiles.clear();
    isRoundTransition = false;
    showDefeatedBoss = false;
    isGameOver = false;
    isGameClear = false;
    isPlaying = true;
    playerX = screenSize.width / 2;
    fireCooldown = 0;
    _flashTimer = 0;

    isLeftPressed = false;
    isRightPressed = false;
    _focusNode.requestFocus();

    double bounceMult = 1.0 + (bossDefeatCount * 0.05);

    // 💡 [개수 증가 규칙 수정] 보스를 깰 때마다(bossDefeatCount) 일반 공 1개씩 추가됨
    int ballCount = 1 + bossDefeatCount;

    balls = [];

    bool isBossRound = (currentRound == 3 || currentRound == 6 || currentRound == 9 || currentRound == 10);

    if (isBossRound) {
      int bossHp = 15;
      if (currentRound == 6) bossHp = 25;
      else if (currentRound == 9) bossHp = 35;
      else if (currentRound == 10) bossHp = 50;

      var boss = Ball(x: screenSize.width / 2, y: 150, vx: 2.0 * bounceMult, vy: 0, sizeLevel: 5, hp: bossHp, bounceSpeedMult: bounceMult);
      boss.isBoss = true;
      balls.add(boss);

      for (int i = 1; i < ballCount; i++) {
        double randomX = 50 + random.nextDouble() * (screenSize.width - 100);
        balls.add(Ball(x: randomX, y: 80 + random.nextDouble()*80, vx: (random.nextBool() ? 1.5 : -1.5) * bounceMult, vy: 0, sizeLevel: 3, hp: 1, bounceSpeedMult: bounceMult));
      }
    } else {
      for (int i = 0; i < ballCount; i++) {
        double randomX = 50 + random.nextDouble() * (screenSize.width - 100);
        balls.add(Ball(x: randomX, y: 80 + random.nextDouble()*80, vx: (random.nextBool() ? 1.5 : -1.5) * bounceMult, vy: 0, sizeLevel: 3, hp: 1, bounceSpeedMult: bounceMult));
      }
    }

    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);
    setState(() {});
  }

  void _gameLoop(Timer timer) {
    if (!isPlaying || isGameOver || isGameClear || isRoundTransition) return;

    setState(() {
      double groundY = screenSize.height - 60;
      if (fireCooldown > 0) fireCooldown--;
      if (_flashTimer > 0) _flashTimer--;

      if (controlMode == 0) {
        double currentSpeed = basePlayerSpeed * (1.0 + (playerSpeedLevel * 0.1));
        if (isLeftPressed) _movePlayerBy(-currentSpeed);
        if (isRightPressed) _movePlayerBy(currentSpeed);
      }

      List<Ball> newClones = [];

      // 💡 [추가 1] 반복문을 돌기 전에 현재 살아있는 분신의 개수를 셉니다!
      int currentCloneCount = balls.where((b) => b.isClone).length;

      for (var ball in balls) {
        if (ball.isBoss) {
          ball.frameCount++;
          if (ball.frameCount % 625 == 0) {
            ball.bounceSpeedMult *= 1.01;
            ball.vx *= 1.01;
          }
          // 1. [순간이동] 약 3초(187프레임)마다 실행ㅎ
          if (ball.frameCount % 187 == 0) {
            if (currentRound == 3 || currentRound == 10) {
              ball.x = 50 + random.nextDouble() * (screenSize.width - 100);
              ball.y = 50 + random.nextDouble() * 100;
            }
            if (currentRound == 10) {
              _flashTimer = 15;
            }
          }

          // 2. [복제] 약 10초(625프레임)마다 실행 👈 이 부분을 새로 만듭니다!
          if (ball.frameCount % 625 == 0) {
            if ((currentRound == 6 || currentRound == 10) && !ball.isClone) {
              if (currentCloneCount + newClones.length < 5) {
                var clone = Ball(x: ball.x, y: ball.y, vx: -ball.vx, vy: ball.vy,
                    sizeLevel: ball.sizeLevel, hp: max(1, ball.hp ~/ 2),
                    bounceSpeedMult: ball.bounceSpeedMult);
                clone.isBoss = true;
                clone.isClone = true;
                newClones.add(clone);
              }
            }
          }
        }

        bool canShootMissile = false;
        if (ball.sizeLevel >= 4) {
          if (ball.isBoss) {
            if (currentRound == 9 || currentRound == 10) canShootMissile = true;
          } else {
            canShootMissile = true;
          }
        }
        if (canShootMissile && random.nextDouble() < 0.015) {
          missiles.add(Missile(x: ball.x, y: ball.y + ball.radius));
        }
      }

      if (newClones.isNotEmpty) {
        balls.addAll(newClones);
      }

      Rect playerRect = Rect.fromLTWH(playerX - playerWidth / 2, groundY - playerHeight - playerWidth, playerWidth, playerHeight + playerWidth);

      for (int i = missiles.length - 1; i >= 0; i--) {
        missiles[i].update(groundY);
        Rect missileRect = Rect.fromLTWH(missiles[i].x - 4, missiles[i].y - 10, 6, 18);
        if (playerRect.overlaps(missileRect)) {
          isGameOver = true; isPlaying = false; gameTimer?.cancel();
        } else if (!missiles[i].active) {
          missiles.removeAt(i);
        }
      }

      for (int a = activeArrows.length - 1; a >= 0; a--) {
        var arrow = activeArrows[a];
        arrow.update(screenSize.width, groundY);
        if (!arrow.active) { activeArrows.removeAt(a); continue; }
        bool arrowHit = false;
        List<Offset> points = List.from(arrow.joints)..add(Offset(arrow.x, arrow.y));
        for (int i = 0; i < balls.length; i++) {
          var ball = balls[i];
          Offset ballCenter = Offset(ball.x, ball.y);
          for (int p = 0; p < points.length - 1; p++) {
            if (_lineCircleIntersect(points[p], points[p+1], ballCenter, ball.radius)) {
              ball.hp--;
              ball.hitTimer = 5;
              if (ball.hp <= 0) _splitBall(i);
              arrowHit = true; break;
            }
          }
          if (arrowHit) break;
        }
        if (arrowHit) activeArrows.removeAt(a);
      }

      for (int i = items.length - 1; i >= 0; i--) {
        items[i].update(groundY);
        Rect itemRect = Rect.fromLTWH(items[i].x - 12, items[i].y - 12, 24, 24);
        if (playerRect.overlaps(itemRect) && items[i].active) {
          if (items[i].type == 0 && maxActiveArrows < 3) maxActiveArrows++;
          else if (items[i].type == 1 && multiShotLevel < 2) multiShotLevel++;
          else if (items[i].type == 2 && arrowBounces < 1) arrowBounces++;
          else if (items[i].type == 3 && playerSpeedLevel < 5) playerSpeedLevel++;
          score += 15; items.removeAt(i);
        } else if (!items[i].active) {
          items.removeAt(i);
        }
      }

      for (int i = 0; i < balls.length; i++) {
        // 💡 [수정 1] 볼의 update를 호출할 때 글로벌 스피드를 넘겨줌
        balls[i].update(screenSize.width, screenSize.height, gravity, globalBallSpeed);

        Offset ballCenter = Offset(balls[i].x, balls[i].y);
        if (_checkIntersect(playerRect, ballCenter, balls[i].radius * 0.75)) {
          isGameOver = true; isPlaying = false; gameTimer?.cancel();
        }
      }

      if (balls.isEmpty) {
        isPlaying = false; gameTimer?.cancel(); isRoundTransition = true;
        isLeftPressed = false; isRightPressed = false;
        if (currentRound == 3 || currentRound == 6 || currentRound == 9 || currentRound == 10) {
          showDefeatedBoss = true;
          bossDefeatCount++;
        }
        Future.delayed(const Duration(seconds: 2), () {
          if (!isGameOver && mounted) {
            if (currentRound >= 10) {
              setState(() { isGameClear = true; });
            } else {
              currentRound++;
              _startRound();
            }
          }
        });
      }
    });
  }

  bool _lineCircleIntersect(Offset A, Offset B, Offset C, double radius) {
    double dx = B.dx - A.dx; double dy = B.dy - A.dy;
    double lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return (C - A).distanceSquared < radius * radius;
    double t = ((C.dx - A.dx) * dx + (C.dy - A.dy) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    Offset projection = Offset(A.dx + t * dx, A.dy + t * dy);
    return (C - projection).distanceSquared < radius * radius;
  }

  bool _checkIntersect(Rect rect, Offset circleCenter, double radius) {
    double closestX = circleCenter.dx.clamp(rect.left, rect.right);
    double closestY = circleCenter.dy.clamp(rect.top, rect.bottom);
    double distanceX = circleCenter.dx - closestX; double distanceY = circleCenter.dy - closestY;
    return (distanceX * distanceX) + (distanceY * distanceY) < (radius * radius);
  }

  void _splitBall(int index) {
    Ball hitBall = balls[index];
    score += hitBall.sizeLevel * 10;
    double rand = random.nextDouble();
    int itemType = -1;
    if (rand < 0.10) itemType = 0;
    else if (rand < 0.15) itemType = 1;
    else if (rand < 0.18) itemType = 2;
    else if (controlMode == 0 && rand < 0.28) itemType = 3;
    if (itemType != -1) items.add(GameItem(x: hitBall.x, y: hitBall.y, type: itemType));
    balls.removeAt(index);
    if (hitBall.sizeLevel > 1) {
      int nextLevel = hitBall.sizeLevel - 1;

      // 💡 스플릿 될 때 속도 역시 globalBallSpeed의 영향을 받게 보정
      double splitVy = (-5.0 - (hitBall.sizeLevel * 0.4)) * hitBall.bounceSpeedMult;
      double baseSplitVx = 1.0 + (5 - hitBall.sizeLevel) * 0.2;
      double splitVx = (baseSplitVx * max(1.0, globalBallSpeed * 1.5)) * hitBall.bounceSpeedMult;

      int nextHp = (nextLevel == 4) ? 5 : 1;
      if (hitBall.sizeLevel == 5) {
        balls.add(Ball(x: hitBall.x - 20, y: hitBall.y, vx: -splitVx * 1.5, vy: splitVy, sizeLevel: nextLevel, hp: nextHp, bounceSpeedMult: hitBall.bounceSpeedMult));
        balls.add(Ball(x: hitBall.x, y: hitBall.y, vx: 0, vy: splitVy - 1.5, sizeLevel: nextLevel, hp: nextHp, bounceSpeedMult: hitBall.bounceSpeedMult));
        balls.add(Ball(x: hitBall.x + 20, y: hitBall.y, vx: splitVx * 1.5, vy: splitVy, sizeLevel: nextLevel, hp: nextHp, bounceSpeedMult: hitBall.bounceSpeedMult));
      } else {
        balls.add(Ball(x: hitBall.x - 10, y: hitBall.y, vx: -splitVx, vy: splitVy, sizeLevel: nextLevel, hp: nextHp, bounceSpeedMult: hitBall.bounceSpeedMult));
        balls.add(Ball(x: hitBall.x + 10, y: hitBall.y, vx: splitVx, vy: splitVy, sizeLevel: nextLevel, hp: nextHp, bounceSpeedMult: hitBall.bounceSpeedMult));
      }
    }
  }

  void _movePlayerBy(double deltaX) {
    if (!isPlaying) return;
    playerX += deltaX;
    playerX = playerX.clamp(playerWidth / 2, screenSize.width - playerWidth / 2);
  }

  void _movePlayerTo(double xPos) {
    if (!isPlaying) return;
    playerX = xPos.clamp(playerWidth / 2, screenSize.width - playerWidth / 2);
  }

  void _fireArrow() {
    if (!isPlaying) return;
    int currentGroups = (activeArrows.length / (multiShotLevel + 1)).ceil();
    if (currentGroups < maxActiveArrows && fireCooldown <= 0) {
      double groundY = screenSize.height - 60;
      setState(() {
        activeArrows.add(Arrow(x: playerX, y: groundY - playerHeight, vx: 0, vy: arrowSpeed, bouncesLeft: arrowBounces, joints: [Offset(playerX, groundY)]));
        if (multiShotLevel >= 1) activeArrows.add(Arrow(x: playerX, y: groundY - playerHeight, vx: -2.5, vy: arrowSpeed, bouncesLeft: arrowBounces, joints: [Offset(playerX, groundY)]));
        if (multiShotLevel >= 2) activeArrows.add(Arrow(x: playerX, y: groundY - playerHeight, vx: 2.5, vy: arrowSpeed, bouncesLeft: arrowBounces, joints: [Offset(playerX, groundY)]));
        fireCooldown = 15;
      });
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    screenSize = MediaQuery.of(context).size;
    bool isBossRound = (currentRound == 3 || currentRound == 6 || currentRound == 9 || currentRound == 10);
    int bgRoundIndex = currentRound <= 10 ? currentRound : 10;
    bool nextIsBoss = (currentRound + 1 == 3 || currentRound + 1 == 6 || currentRound + 1 == 9 || currentRound + 1 == 10);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (selectionState != 3 || controlMode != 0) return KeyEventResult.ignored;
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.keyA) isLeftPressed = true;
            else if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.keyD) isRightPressed = true;
            else if (event.logicalKey == LogicalKeyboardKey.space) _fireArrow();
          } else if (event is KeyUpEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.keyA) isLeftPressed = false;
            else if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.keyD) isRightPressed = false;
          }
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          onTapDown: (details) {
            if (selectionState == 3) {
              if (controlMode == 1) {
                setState(() => _movePlayerTo(details.localPosition.dx));
                _fireArrow();
              } else if (controlMode == 2) {
                setState(() => _movePlayerTo(details.localPosition.dx));
              } else {
                _focusNode.requestFocus();
              }
            }
          },
          onPanUpdate: (details) {
            if (selectionState == 3 && (controlMode == 1 || controlMode == 2)) {
              setState(() => _movePlayerTo(details.localPosition.dx));
            }
          },
          onTapUp: (details) {
            if (selectionState == 3 && controlMode == 2) {
              _fireArrow();
            }
          },
          onPanEnd: (details) {
            if (selectionState == 3 && controlMode == 2) {
              _fireArrow();
            }
          },
          child: Stack(
            children: [
              if (selectionState == 3)
                Container(
                  width: double.infinity, height: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/backgr/round$bgRoundIndex.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: CustomPaint(
                    painter: GamePainter(
                      playerX: playerX, playerWidth: playerWidth, playerHeight: playerHeight, groundY: screenSize.height - 60,
                      balls: balls, arrows: activeArrows, items: items, missiles: missiles,
                      characterFace: selectedPlayerImage, bossFace: selectedBossImage, bodyImage: GameImages.bodyImage,
                    ),
                  ),
                ),

              if (selectionState == 3 && _flashTimer > 0)
                Container(
                  width: double.infinity, height: double.infinity,
                  color: Colors.red.withOpacity(0.4),
                ),

              if (selectionState == 3) ...[
                Positioned(
                  top: 40, left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                        child: Text("SCORE: $score", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                        child: Text("ROUND $currentRound / 10", style: TextStyle(color: isBossRound ? Colors.redAccent : Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildStatusIcon("C", maxActiveArrows, Colors.yellow),
                          const SizedBox(width: 5),
                          _buildStatusIcon("M", multiShotLevel, Colors.cyanAccent),
                          const SizedBox(width: 5),
                          _buildStatusIcon("B", arrowBounces, Colors.pinkAccent),
                          if (controlMode == 0) ...[
                            const SizedBox(width: 5),
                            _buildStatusIcon("S", playerSpeedLevel, Colors.greenAccent),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),

                if (isRoundTransition && !isGameOver && !isGameClear && !showDefeatedBoss)
                  Center(
                    child: Text(nextIsBoss ? "⚠️ BOSS APPROACHING ⚠️" : "ROUND CLEAR!",
                        textAlign: TextAlign.center, style: TextStyle(color: nextIsBoss ? Colors.redAccent : Colors.greenAccent, fontSize: 36, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black, blurRadius: 10)])),
                  ),

                if (showDefeatedBoss && selectedBossImage != null)
                  Center(
                    child: Container(
                      width: 250, height: 250,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.red, width: 5)),
                      child: ClipOval(
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.matrix([0.8, 0, 0, 0, 50, 0, 0.3, 0, 0, 0, 0, 0, 0.3, 0, 0, 0, 0, 0, 1, 0]),
                          child: RawImage(image: selectedBossImage, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
              ],

              if (selectionState == 0)
                _buildSelectionScreen("내 캐릭터를 선택하세요!", [GameImages.doImage, GameImages.soImage, GameImages.c1Image, GameImages.c2Image], ["도유니", "소미니", "윤오", "윤성이"], _onPlayerSelected),

              if (selectionState == 1)
                _buildSelectionScreen("오늘의 보스는 누구?", [GameImages.b1Image, GameImages.b2Image, GameImages.b3Image, GameImages.b4Image], ["떼쟁이", "삐돌이", "울보", "코딱지"], _onBossSelected),

              if (selectionState == 2)
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("조작 방식을 선택하세요", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 50),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildModeButton(Icons.keyboard, "키보드", "A, D 이동\nSpace 발사", () => _onModeSelected(0)),
                            _buildModeButton(Icons.touch_app, "스마트폰 1", "화면 터치 시\n즉시 이동/발사", () => _onModeSelected(1)),
                            _buildModeButton(Icons.swipe, "스마트폰 2", "드래그로 이동\n손 떼면 발사", () => _onModeSelected(2)),
                          ],
                        ),

                        if (isTestMode) ...[
                          const SizedBox(height: 60),
                          const Text("--- 테스트 바로가기 ---", style: TextStyle(color: Colors.white54, fontSize: 14)),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildJumpButton("보스1", () => _jumpTo(3)),
                              _buildJumpButton("보스2", () => _jumpTo(6)),
                              _buildJumpButton("보스3", () => _jumpTo(9)),
                              _buildJumpButton("보스4", () => _jumpTo(10)),
                              _buildJumpButton("완료", () => _jumpTo(0, clear: true), color: Colors.green),
                            ],
                          )
                        ]
                      ],
                    ),
                  ),
                ),

              if (selectionState == 3 && (isGameOver || isGameClear))
                Container(
                  color: Colors.black.withAlpha(230),
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(isGameClear ? "🎉 ALL CLEAR! 🎉" : "💀 GAME OVER 💀",
                             style: TextStyle(color: isGameClear ? Colors.greenAccent : Colors.redAccent, fontSize: 50, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 30),
                        const Text("TOTAL SCORE", style: TextStyle(color: Colors.white70, fontSize: 20)),
                        Text("$score", style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: ui.FontWeight.w900, letterSpacing: 5)),
                        if (!isGameClear) Text("Reached Round: $currentRound", style: const TextStyle(color: Colors.white70, fontSize: 18)),
                        const SizedBox(height: 60),
                        ElevatedButton(
                          onPressed: () => setState(() => selectionState = 0),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                          ),
                          child: Text(isGameClear ? "다시하기" : "처음으로", style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJumpButton(String label, VoidCallback onTap, {Color color = Colors.blueGrey}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color, minimumSize: const Size(60, 40), padding: EdgeInsets.zero),
        child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
      ),
    );
  }

  Widget _buildStatusIcon(String label, int level, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text("$label $level", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSelectionScreen(String title, List<ui.Image?> images, List<String> labels, Function(ui.Image?) onSelected) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFaceButton(images[0], labels[0], () => onSelected(images[0])),
                const SizedBox(width: 20),
                _buildFaceButton(images[1], labels[1], () => onSelected(images[1])),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFaceButton(images[2], labels[2], () => onSelected(images[2])),
                const SizedBox(width: 20),
                _buildFaceButton(images[3], labels[3], () => onSelected(images[3])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceButton(ui.Image? img, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.orangeAccent, width: 3)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: img != null ? RawImage(image: img, fit: BoxFit.cover) : const Icon(Icons.person, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildModeButton(IconData icon, String title, String desc, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange, width: 3)),
            child: Icon(icon, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  final double playerX, playerWidth, playerHeight, groundY;
  final List<Ball> balls;
  final List<Arrow> arrows;
  final List<GameItem> items;
  final List<Missile> missiles;
  final ui.Image? characterFace;
  final ui.Image? bossFace;
  final ui.Image? bodyImage;

  GamePainter({required this.playerX, required this.playerWidth, required this.playerHeight, required this.groundY, required this.balls, required this.arrows, required this.items, required this.missiles, required this.characterFace, required this.bossFace, required this.bodyImage});

  void _drawSinuousLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    double dx = p2.dx - p1.dx; double dy = p2.dy - p1.dy;
    double length = sqrt(dx * dx + dy * dy);
    if (length == 0) return;
    double nx = -dy / length; double ny = dx / length;
    Path path = Path(); path.moveTo(p1.dx, p1.dy);
    for (double i = 0; i <= length; i += 2.0) {
      double t = i / length; double cx = p1.dx + dx * t; double cy = p1.dy + dy * t;
      double waveAmplitude = 6.0 * cos(i / 8.0);
      path.lineTo(cx + nx * waveAmplitude, cy + ny * waveAmplitude);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    paint.color = Colors.black.withOpacity(0.4);
    canvas.drawRect(Rect.fromLTWH(0, groundY, size.width, size.height - groundY), paint);

    for (var arrow in arrows) {
      paint.color = Colors.white; paint.strokeWidth = 3; paint.style = PaintingStyle.stroke;
      List<Offset> points = List.from(arrow.joints)..add(Offset(arrow.x, arrow.y));
      for (int i = 0; i < points.length - 1; i++) _drawSinuousLine(canvas, points[i], points[i+1], paint);
      canvas.save(); canvas.translate(arrow.x, arrow.y); canvas.rotate(atan2(-arrow.vy, arrow.vx) + pi / 2);
      paint.color = Colors.redAccent; paint.style = PaintingStyle.fill;
      canvas.drawPath(Path()..moveTo(0, -15)..lineTo(-10, 10)..lineTo(10, 10)..close(), paint);
      canvas.restore();
    }

    for (var item in items) {
      if (item.groundTimer > 200 && (item.groundTimer ~/ 10) % 2 == 0) continue;
      Color itemColor = item.type == 0 ? Colors.yellow : item.type == 1 ? Colors.cyanAccent : item.type == 2 ? Colors.pinkAccent : Colors.greenAccent;
      String itemLabel = item.type == 0 ? "C" : item.type == 1 ? "M" : item.type == 2 ? "B" : "S";
      paint.color = itemColor;
      paint.style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(item.x - 12, item.y - 12, 24, 24), const Radius.circular(5)), paint);
      TextSpan span = TextSpan(style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold), text: itemLabel);
      TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(item.x - tp.width / 2, item.y - tp.height / 2));
    }

    for (var m in missiles) {
      // 1. 먼저 은은하게 빛나는 바깥쪽 후광(Glow)을 큼직하게 그립니다.
      paint.color = Colors.red.withOpacity(0.8); // 투명도 40%
      paint.style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(m.x - 6, m.y - 12, 12, 24), const Radius.circular(5)), paint);

      // 2. 그 위에 선명하고 밝은 진짜 미사일 본체를 그립니다.
      paint.color = Colors.white; // 코어는 하얗게!
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(m.x - 2, m.y - 8, 4, 16), const Radius.circular(2)), paint);
    }

    if (bodyImage != null) {
      Rect bodyRect = Rect.fromLTWH(playerX - playerWidth / 2, groundY - playerHeight, playerWidth, playerHeight);
      paintImage(canvas: canvas, rect: bodyRect, image: bodyImage!, fit: BoxFit.fill);
    } else {
      paint.style = PaintingStyle.fill; paint.color = Colors.blue;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(playerX - 15, groundY - playerHeight + 20, 30, 20), const Radius.circular(5)), paint);
    }

    if (characterFace != null) {
      Rect faceRect = Rect.fromLTWH(playerX - playerWidth / 2, groundY - playerHeight - playerWidth, playerWidth, playerWidth);
      canvas.save(); canvas.clipPath(Path()..addRect(faceRect));
      paintImage(canvas: canvas, rect: faceRect, image: characterFace!, fit: BoxFit.cover);
      canvas.restore();
    }

    for (var ball in balls) {
      if (ball.hitTimer > 0) paint.color = Colors.white;
      else paint.shader = ui.Gradient.radial(Offset(ball.x - ball.radius * 0.3, ball.y - ball.radius * 0.3), ball.radius, [Colors.white, ball.baseColor, Colors.black87], [0.0, 0.5, 1.0]);
      canvas.drawCircle(Offset(ball.x, ball.y), ball.radius, paint);
      paint.shader = null;

      if (ball.sizeLevel >= 4 && bossFace != null) {
        double faceR = ball.radius * 0.8;
        Rect faceRect = Rect.fromCircle(center: Offset(ball.x, ball.y), radius: faceR);
        canvas.save(); canvas.clipPath(Path()..addOval(faceRect));
        paintImage(canvas: canvas, rect: faceRect, image: bossFace!, fit: BoxFit.cover);
        canvas.restore();

        paint.style = PaintingStyle.fill; paint.color = Colors.black;
        canvas.drawPath(Path()..moveTo(ball.x - ball.radius * 0.5, ball.y - ball.radius * 0.6)..lineTo(ball.x - ball.radius * 0.8, ball.y - ball.radius * 1.2)..lineTo(ball.x - ball.radius * 0.1, ball.y - ball.radius * 0.8)..close(), paint);
        canvas.drawPath(Path()..moveTo(ball.x + ball.radius * 0.5, ball.y - ball.radius * 0.6)..lineTo(ball.x + ball.radius * 0.8, ball.y - ball.radius * 1.2)..lineTo(ball.x + ball.radius * 0.1, ball.y - ball.radius * 0.8)..close(), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}