# 素材生成の記録

生成日: 2026-09-16。画像生成はimage_genの組み込みモードを使用。
人物アニメーションはユーザー提供画像を参照し、クイヤは独自のデザインとして生成。
元画像は加工せず保管し、ゲーム側のアトラス座標でコマを切り出す。

## action_sprites.png

生成結果: 1122 × 1402 / RGBA / 4列5行。上から筋トレ・お風呂・星粒メモリー・整体・カメラ救出。

```text
Use case: stylized-concept. Asset type: one production pixel-art character animation sprite atlas for a Ruby/Gosu comedy livestream game, 4 columns x 5 rows (20 equal cells), canvas 1024x1280, cell size 256x256. Reference image 1 supplies the SAME fictional adult male character's identity: short tousled dark brown hair, large expressive eyes, tan skin, angular smiling face, muscular arms. Preserve that recognizability consistently.
Create all 20 separate frames in a precisely regular grid, no grid lines, absolutely no text, labels or watermarks. Fully transparent background outside sprites. Each character and props must fit inside the central 220x220 of their cell with a generous clear margin, ground baseline y=224 within each cell. Every row keeps the same camera and character scale. Crisp square pixel clusters, limited 16-bit game palette, dark pixel outlines, approx 80x80 effective pixel resolution upscaled nearest-neighbor, no smooth painting. Charming exaggerated slapstick.
Row 1 TRAINING, four sequential looping frames: shirtless with dark navy shorts, enormous toy dumbbells at hips; weights halfway up with puffed cheeks; weights lifted proudly with comically huge eyes; weights lowered with a tiny sweat drop.
Row 2 BATH, four sequential looping frames: seated inside a small turquoise bubble bathtub, opaque tub and foam fully covering body from shoulders down, same adult male head and upper shoulders visible; rubber duck at side; duck bouncing with splashing foam; duck on his head and hilariously startled eyes; duck sliding back into water.
Row 3 FANTASY SUPPLEMENT, four sequential frames: same character wearing aqua T-shirt and navy shorts holding a small purple bottle with a star symbol (no words); tilts a single imaginary star candy toward mouth; cartoon sparkle cheeks; smug thumbs-up with tiny star sparkles. No real medicine, no piles of pills.
Row 4 MASSAGE CHAIR, four sequential frames: same character fully dressed in aqua T-shirt and navy shorts sitting on a mauve reclining massage chair; relaxed but awake; head droops sideways with eyelids descending; eyes pop wide open with cartoon surprise; recovered proud upright pose. Show chair in all four cells.
Row 5 CAMERA RESCUE, four sequential frames: same fully dressed character beside a tiny lavender camera on tripod; camera tilts and he throws arms out; he catches the camera in a comically dramatic lunging pose; re-centered camera and relieved thumbs-up. Fully clothed in all four cells.
Reference is an identity/style guide only. This atlas is a fictional humorous game asset, not a depiction of any real intimate incident. Maintain clean separation of cells and true alpha transparency.
```

## kuiya_sprites.png

生成結果: 1254 × 1254 / RGBA / 2列2行。覗く・歩く・驚く・逃げる。

```text
Use case: stylized-concept. Asset type: a single 2x2 pixel-art animation sprite sheet for a fictional internet creature called Kuiya, on true transparent background, square 1024x1024 canvas. Four equal 512x512 cells without lines, no text or watermark. This is an ORIGINAL visual interpretation of a fictional meme creature, not an existing mascot. Cute uncanny little tan guinea-pig/beaver-like animal, tubby pear-shaped body, small round ears, huge inquisitive violet eyes, two small square front teeth, a visible curled dark brown tail. Match a cozy 16-bit pixel game with crisp chunky square pixel clusters and dark-purple pixel outlines, approx 64x64 effective pixel resolution in each cell. Same proportions in all cells, centered with at least 70px transparent padding on all sides. Frame 1 inquisitively peeking, head tilted; frame 2 tiny walking pose, one paw forward and tail lifted; frame 3 comically startled recoiling pose with big eyes (it is frightened of the number 9, but do NOT draw numbers); frame 4 turning to run away with little dust pixels. Mildly surreal and funny, no horror gore, no photorealism. Keep each frame isolated in its cell for cutting into animation frames.
```

