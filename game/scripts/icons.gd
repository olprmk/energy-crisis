class_name Icons
extends RefCounted
## UI icons from the Figma design (KeyLock / game page): SVGs are embedded so they work in exported builds.

const LOGO_SVG := """<svg width="32" height="32" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">
<rect x="1" y="1" width="30" height="30" rx="5" fill="#FFAE00"/>
<g transform="translate(5.889 5.111)"><g id="Group 6">
<path id="Vector" d="M14.4445 20.0001V21.1113" stroke-width="2.22222" stroke-linecap="square" stroke="#CA8A00"/>
<path id="Vector 1" d="M4.62005 8.65309L6.11111 7.88894V6.62067L8.19583 2.56265L11.6111 0.888943L12.6111 6.88894L14.2427 8.88894H21.1111L20.4862 11.4797L18.1459 15.0496L16.0753 17.9769L13.8533 21.8382L13.1111 22.3889L11.1111 23.3889L9.61111 17.3889L8.61111 16.3889L1.61111 15.3889V13.101L4.62005 8.65309Z" fill="#CA8A00"/>
<path id="Vector_2" d="M10 17.7779V23.3334H12.2222" stroke-width="2.22222" stroke-linecap="square" stroke="#CA8A00"/>
<path id="Vector_3" d="M16.6667 16.6668V17.7779" stroke-width="2.22222" stroke-linecap="square" stroke="#CA8A00"/>
<path id="Vector_4" d="M7.77778 15.5556H1.11111V13.3334" stroke-width="2.22222" stroke-linecap="square" stroke="#CA8A00"/>
<path id="Vector_5" d="M18.8889 13.3334V14.4445" stroke-width="2.22222" stroke-linecap="square" stroke="#CA8A00"/>
<path id="Vector_6" d="M3.33329 10.0001L3.33328 11.1113" stroke-width="2.22222" stroke-linecap="square" stroke="#CA8A00"/>
<path id="Vector_7" d="M14.4445 8.88894H21.1112V11.1112" stroke-width="2.22222" stroke-linecap="square" stroke="#CA8A00"/>
<path id="Vector_8" d="M5.55557 6.66678L5.55558 7.77789" stroke-width="2.22222" stroke-linecap="square" stroke="#CA8A00"/>
<path id="Vector_9" d="M7.77774 3.3334L7.77775 4.44451" stroke-width="2.22222" stroke-linecap="square" stroke="#CA8A00"/>
<path id="Vector_10" d="M12.2222 6.66667V1.11111H10" stroke-width="2.22222" stroke-linecap="square" stroke="#CA8A00"/>
</g></g>
<g transform="translate(4.889 4.111)"><g id="Group 7">
<path id="Vector" d="M14.4445 20.0001V21.1113" stroke-width="2.22222" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector 1" d="M4.62005 8.65309L6.11111 7.88894V6.62067L8.19583 2.56265L11.6111 0.888943L12.6111 6.88894L14.2427 8.88894H21.1111L20.4862 11.4797L18.1459 15.0496L16.0753 17.9769L13.8533 21.8382L13.1111 22.3889L11.1111 23.3889L9.61111 17.3889L8.61111 16.3889L1.61111 15.3889V13.101L4.62005 8.65309Z" fill="#2C1E02"/>
<path id="Vector_2" d="M10 17.7779V23.3334H12.2222" stroke-width="2.22222" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_3" d="M16.6667 16.6668V17.7779" stroke-width="2.22222" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_4" d="M7.77778 15.5556H1.11111V13.3334" stroke-width="2.22222" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_5" d="M18.8889 13.3334V14.4445" stroke-width="2.22222" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_6" d="M3.33329 10.0001L3.33328 11.1113" stroke-width="2.22222" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_7" d="M14.4445 8.88894H21.1112V11.1112" stroke-width="2.22222" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_8" d="M5.55557 6.66678L5.55558 7.77789" stroke-width="2.22222" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_9" d="M7.77774 3.3334L7.77775 4.44451" stroke-width="2.22222" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_10" d="M12.2222 6.66667V1.11111H10" stroke-width="2.22222" stroke-linecap="square" stroke="#2C1E02"/>
</g></g>
</svg>"""

## The result stars (Figma KeyLock "Success", 50 x 50): a rounded star, a yellow-to-orange gradient when earned,
## the grey of the "Restart game" button (#CFD8DB) when not.
const STAR_SVG := """<svg width="50" height="50" viewBox="0 0 50 50" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M27.085 4.623 L31.794 15.067 A0.690 0.690 0 0 0 32.348 15.469 L43.735 16.721 A2.287 2.287 0 0 1 45.024 20.686 L36.546 28.392 A0.690 0.690 0 0 0 36.335 29.043 L38.664 40.260 A2.287 2.287 0 0 1 35.291 42.711 L25.342 37.029 A0.690 0.690 0 0 0 24.658 37.029 L14.709 42.711 A2.287 2.287 0 0 1 11.336 40.260 L13.665 29.043 A0.690 0.690 0 0 0 13.454 28.392 L4.976 20.686 A2.287 2.287 0 0 1 6.265 16.721 L17.652 15.469 A0.690 0.690 0 0 0 18.206 15.067 L22.915 4.623 A2.287 2.287 0 0 1 27.085 4.623 Z" fill="url(#g)"/>
<defs><linearGradient id="g" x1="25" y1="3.28" x2="25" y2="43.01" gradientUnits="userSpaceOnUse">
<stop stop-color="#FBE44D"/><stop offset="1" stop-color="#DC7A4B"/></linearGradient></defs>
</svg>"""

const STAR_GREY_SVG := """<svg width="50" height="50" viewBox="0 0 50 50" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M27.085 4.623 L31.794 15.067 A0.690 0.690 0 0 0 32.348 15.469 L43.735 16.721 A2.287 2.287 0 0 1 45.024 20.686 L36.546 28.392 A0.690 0.690 0 0 0 36.335 29.043 L38.664 40.260 A2.287 2.287 0 0 1 35.291 42.711 L25.342 37.029 A0.690 0.690 0 0 0 24.658 37.029 L14.709 42.711 A2.287 2.287 0 0 1 11.336 40.260 L13.665 29.043 A0.690 0.690 0 0 0 13.454 28.392 L4.976 20.686 A2.287 2.287 0 0 1 6.265 16.721 L17.652 15.469 A0.690 0.690 0 0 0 18.206 15.067 L22.915 4.623 A2.287 2.287 0 0 1 27.085 4.623 Z" fill="#CFD8DB"/>
</svg>"""

## Pixel icons, 10x10 grid of 2x2 blocks (top-left corners), traced from the Figma frames.
## The redesign (Figma KeyLock 48:2814): the big logo of the start panel, the bolt of the load meter and the curved
## arrow of the controls hint (white, plus a soft dark edge drawn under it). Embedded, not image files: they work
## without the editor importing anything (also when the game is run straight from the Project Manager).
const LOGO_BIG_SVG := """<svg preserveAspectRatio="none" overflow="visible" style="display: block;" width="66" height="66" viewBox="0 0 66 66" fill="none" xmlns="http://www.w3.org/2000/svg">
<g id="Group 9">
<path id="Vector" d="M63.9401 8.24793V4.1281H61.8719V2.05991H57.7521V0H53.624V2.05991V0H49.4959H45.376V2.05991V0H41.2479V2.05991V0H37.1281V2.05991V0H33H28.8719V2.05991V0H24.7521H20.624V2.05991V0H16.5041H12.376V2.05991V0H8.24793V2.05991H4.1281V4.1281H2.06819V8.24793H0V12.376V16.4959V20.624V24.7521V28.8719H2.06819H0V33H2.06819H0V37.1198H2.06819H0V41.2479H2.06819H0V45.376V49.4959H2.06819H0V53.624H2.06819H0V57.7438H2.92855H2.06819V61.8719H4.1281V63.9318H8.24793V66H12.376V63.9318V65.9917H16.5041H20.624V63.9318V65.9917H24.7521H28.8719V63.9318V65.9917H33H37.1281V63.9318V65.9917H41.2479V63.9318V65.9917H45.376V63.9318V65.9917H49.4959H53.624V63.9318V66H57.7521V63.9318H61.8719V61.8719H63.9401V57.7438H63.0715H66V53.624H63.9401H66V49.4959H63.9401H66V45.376V41.2479H63.9401H66V37.1198H63.9401H66V33H63.9401H66V28.8719H63.9401H66V24.7521V20.624V16.4959V12.376V8.24793H63.9401Z" fill="url(#paint0_linear_0_4)"/>
<g id="Group">
<path id="Vector_2" d="M40.0318 48.5858V50.4968" stroke-width="3.83028" stroke-linecap="square" stroke="#C98B2B"/>
<path id="Vector_3" d="M23.1056 29.0292L25.6784 27.7138V25.5298L29.2688 18.5394L35.1507 15.6522L36.8715 25.9931L39.6842 29.4428H51.5225L50.4471 33.9101L46.4182 40.0651L42.8527 45.1114L39.0224 51.7627L37.7401 52.7141L34.2904 54.4348L31.7093 44.0939L29.9885 42.3732L17.9269 40.6524V36.7063L23.1139 29.0458L23.1056 29.0292Z" fill="#C98B2B"/>
<path id="Vector_4" d="M32.3793 44.7556V54.3272H36.2096" stroke-width="3.83028" stroke-linecap="square" stroke="#C98B2B"/>
<path id="Vector_5" d="M43.8618 42.8363V44.7473" stroke-width="3.83028" stroke-linecap="square" stroke="#C98B2B"/>
<path id="Vector_6" d="M28.5491 40.9254H17.0582V37.0951" stroke-width="3.83028" stroke-linecap="square" stroke="#C98B2B"/>
<path id="Vector_7" d="M47.6921 37.0951V39.0061" stroke-width="3.83028" stroke-linecap="square" stroke="#C98B2B"/>
<path id="Vector_8" d="M20.8886 31.3538V33.2648" stroke-width="3.83028" stroke-linecap="square" stroke="#C98B2B"/>
<path id="Vector_9" d="M40.0318 29.4345H51.5226V33.2648" stroke-width="3.83028" stroke-linecap="square" stroke="#C98B2B"/>
<path id="Vector_10" d="M24.7186 25.6126V27.5236" stroke-width="3.83028" stroke-linecap="square" stroke="#C98B2B"/>
<path id="Vector_11" d="M28.5493 19.8629V21.7739" stroke-width="3.83028" stroke-linecap="square" stroke="#C98B2B"/>
<path id="Vector_12" d="M36.2013 25.6125V16.041H32.371" stroke-width="3.83028" stroke-linecap="square" stroke="#C98B2B"/>
<path id="Vector_13" d="M38.3111 46.857V48.768" stroke-width="3.83028" stroke-linecap="square" stroke="black"/>
<path id="Vector_14" d="M21.3845 27.3084L23.9573 25.993V23.809L27.5477 16.8186L33.4296 13.9314L35.1504 24.2723L37.9631 27.722H49.8014L48.7259 32.1893L44.6971 38.3443L41.1316 43.3906L37.3013 50.0419L36.019 50.9933L32.5693 52.714L29.9882 42.3731L28.2674 40.6524L16.2058 38.9316V34.9855L21.3928 27.325L21.3845 27.3084Z" fill="black"/>
<path id="Vector_15" d="M30.6503 43.0349V52.6064H34.4806" stroke-width="3.83028" stroke-linecap="square" stroke="black"/>
<path id="Vector_16" d="M42.141 41.1157V43.0267" stroke-width="3.83028" stroke-linecap="square" stroke="black"/>
<path id="Vector_17" d="M26.8283 39.2046H15.3375V35.3743" stroke-width="3.83028" stroke-linecap="square" stroke="black"/>
<path id="Vector_18" d="M45.9714 35.3743V37.2853" stroke-width="3.83028" stroke-linecap="square" stroke="black"/>
<path id="Vector_19" d="M19.1675 29.633V31.5441" stroke-width="3.83028" stroke-linecap="square" stroke="black"/>
<path id="Vector_20" d="M38.3111 27.7137H49.8019V31.544" stroke-width="3.83028" stroke-linecap="square" stroke="black"/>
<path id="Vector_21" d="M22.9979 23.8835V25.7945" stroke-width="3.83028" stroke-linecap="square" stroke="black"/>
<path id="Vector_22" d="M26.8199 18.1423V20.0533" stroke-width="3.83028" stroke-linecap="square" stroke="black"/>
<path id="Vector_23" d="M34.4806 23.8835V14.3119H30.6503" stroke-width="3.83028" stroke-linecap="square" stroke="black"/>
</g>
</g>
<defs>
<linearGradient id="paint0_linear_0_4" x1="33" y1="0" x2="33" y2="66" gradientUnits="userSpaceOnUse">
<stop stop-color="#FFF33B"/>
<stop offset="0.04" stop-color="#FEE62D"/>
<stop offset="0.12" stop-color="#FDD51B"/>
<stop offset="0.2" stop-color="#FDCA0F"/>
<stop offset="0.28" stop-color="#FDC70C"/>
<stop offset="0.67" stop-color="#F3903F"/>
<stop offset="0.89" stop-color="#ED683C"/>
<stop offset="1" stop-color="#E93E3A"/>
</linearGradient>
</defs>
</svg>"""

const HUD_BOLT_SVG := """<svg preserveAspectRatio="none" overflow="visible" style="display: block;" width="15.4481" height="17.1111" viewBox="0 0 15.4481 17.1111" fill="none" xmlns="http://www.w3.org/2000/svg">
<g id="Group 7">
<path id="Vector" d="M10.0393 14.0001V14.7779" stroke-width="1.55555" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector 1" d="M3.28017 6.05715L4.32391 5.52225V4.63446L5.78321 1.79385L8.17391 0.622259L8.8739 4.82225L10.016 6.22225H14.8239L14.3864 8.03574L12.7482 10.5347L11.2988 12.5838L9.74343 15.2867L9.2239 15.6722L7.82391 16.3722L6.77391 12.1722L6.07391 11.4722L1.17392 10.7722V9.17071L3.28017 6.05715Z" fill="#2C1E02"/>
<path id="Vector_2" d="M6.95269 12.4445V16.3334H8.49637" stroke-width="1.55555" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_3" d="M11.5843 11.6667V12.4445" stroke-width="1.55555" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_4" d="M5.40881 10.8889H0.777776V9.33338" stroke-width="1.55555" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_5" d="M13.1276 9.33338V10.1112" stroke-width="1.55555" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_6" d="M2.32109 7.00008L2.32108 7.77786" stroke-width="1.55555" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_7" d="M10.0393 6.22223H14.6703V7.77778" stroke-width="1.55555" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_8" d="M3.86438 4.66673L3.86439 5.44451" stroke-width="1.55555" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_9" d="M5.40938 2.33338L5.40939 3.11116" stroke-width="1.55555" stroke-linecap="square" stroke="#2C1E02"/>
<path id="Vector_10" d="M8.49637 4.66666V0.777776H6.95269" stroke-width="1.55555" stroke-linecap="square" stroke="#2C1E02"/>
</g>
</svg>"""

const HINT_ARROW_SVG := """<svg width="66.9669" height="41.9605" viewBox="-2 -2 66.9669 41.9605" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M62.8984 0.960532L62.9669 0.465246C47.8547 -1.62474 15.4022 2.30761 2.05526 33.5631L2.51509 33.7594L2.97492 33.9558C16.0628 3.30703 47.9168 -0.606624 62.8299 1.45582L62.8984 0.960532ZM0.898365 37.9605L5.38828 34.3309L0 32.2574L0.898365 37.9605Z" fill="white"/>
</svg>"""

const HINT_ARROW_EDGE_SVG := """<svg width="66.9669" height="41.9605" viewBox="-2 -2 66.9669 41.9605" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M62.8984 0.960532L62.9669 0.465246C47.8547 -1.62474 15.4022 2.30761 2.05526 33.5631L2.51509 33.7594L2.97492 33.9558C16.0628 3.30703 47.9168 -0.606624 62.8299 1.45582L62.8984 0.960532ZM0.898365 37.9605L5.38828 34.3309L0 32.2574L0.898365 37.9605Z" fill="#2C1E02" stroke="#2C1E02" stroke-width="3" stroke-linejoin="round"/>
</svg>"""

## The arrow pictures above: the drawn arrow's own size (Figma 62 x 37.46) and how far the padded picture reaches
## past it on each side (2 SVG units).
const HINT_ARROW_SIZE := Vector2(62.0, 37.46)
const HINT_ARROW_PAD := 2.0 * 62.0 / 62.9669

const ARROW_LEFT := [Vector2(0, 4), Vector2(2, 6), Vector2(2, 4), Vector2(4, 4), Vector2(6, 4), Vector2(8, 4), Vector2(4, 8), Vector2(2, 2), Vector2(4, 0)]
const ARROW_RIGHT := [Vector2(8, 4), Vector2(6, 2), Vector2(6, 4), Vector2(4, 4), Vector2(2, 4), Vector2(0, 4), Vector2(4, 0), Vector2(6, 6), Vector2(4, 8)]
const ENTER := [Vector2(0, 6), Vector2(2, 8), Vector2(2, 6), Vector2(4, 6), Vector2(6, 6), Vector2(7, 5), Vector2(8, 2), Vector2(8, 0), Vector2(2, 4), Vector2(1, 5), Vector2(1, 7), Vector2(8, 4)]

static var _cache := {}


## Redrawable PNG override: res://assets/ui/<name>.png (any resolution; drawn at the design size).
static func png(name: String) -> Texture2D:
	var path := "res://assets/ui/%s.png" % name
	if ResourceLoader.exists(path):
		return load(path)
	return null


static func svg(key: String, source: String, px: int) -> Texture2D:
	## Rasterise an SVG at 4x for crisp results on HiDPI screens.
	var k := "%s@%d" % [key, px]
	if _cache.has(k):
		return _cache[k]
	var img := Image.new()
	img.load_svg_from_string(source, 4.0 * px / 32.0)
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex


static func svg_scaled(key: String, source: String, scale: float) -> Texture2D:
	## Rasterise an SVG at `scale` times its own size (4 = crisp on HiDPI screens and when the HUD is enlarged).
	var k := "%s*%s" % [key, scale]
	if _cache.has(k):
		return _cache[k]
	var img := Image.new()
	img.load_svg_from_string(source, scale)
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex


static func pixel(key: String, blocks: Array, color: Color) -> Texture2D:
	var k := "%s#%s" % [key, color.to_html()]
	if _cache.has(k):
		return _cache[k]
	const S := 4   # 10x10 design pixels -> 40x40 texture
	var img := Image.create(10 * S, 10 * S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for b in blocks:
		var p: Vector2 = b
		img.fill_rect(Rect2i(int(p.x * S), int(p.y * S), 2 * S, 2 * S), color)
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex
