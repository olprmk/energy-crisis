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

const STAR_SVG := """<svg preserveAspectRatio="none" overflow="visible" style="display: block;" width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
<g id="result-star 1">
<path id="Vector 2" d="M11.2938 10.2463L12.5812 8.64209L14.4925 4.17446L15.6104 3.14796L17.1204 3.70357L18.0463 4.97109L19.7734 8.85213L20.6543 10.7479L29.4026 10.9856L28.4686 14.1212L26.6578 16.2576L24.7147 17.8344L24.6129 20.9881L26.2 21.7511L25.9965 27.5397L24.5316 27.7024L21.5406 26.8581L18.8651 24.2537L18.3361 23.5009L13.6971 23.6738L10.9096 26.3698L10.5434 26.8886L5.45236 28.1993L6.16398 21.6746L6.95623 21.1794V17.6539L4.04471 14.8216L3.17324 11.6724L11.2938 10.2463Z" fill="#FFAE00"/>
<path id="Vector" d="M16 2.68001V2.66668" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_2" d="M12 25.3467V25.3333" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_3" d="M20 25.3467V25.3333" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_4" d="M5.33333 16.0133V16" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_5" d="M26.6667 16.0133V16" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_6" d="M5.33333 22.6667V28H9.33333" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_7" d="M26.6667 22.6667V28H22.6667" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_8" d="M14.6667 22.6667H17.3333" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_9" d="M10.6667 10.6667H2.66667V13.3333" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_10" d="M21.3333 10.6667H29.3333V13.3333" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_11" d="M24 18.6667V20" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_12" d="M8 18.6667V20" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_13" d="M18.6667 5.33333V8" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
<path id="Vector_14" d="M13.3333 5.33333V8" stroke-width="2.66667" stroke-linecap="square" stroke="#FFAE00"/>
</g>
</svg>
"""

const STAR_GREY_SVG := """<svg preserveAspectRatio="none" overflow="visible" style="display: block;" width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
<g id="result-star 1">
<path id="Vector 2" d="M11.2938 10.2463L12.5812 8.64209L14.4925 4.17446L15.6104 3.14796L17.1204 3.70357L18.0463 4.97109L19.7734 8.85213L20.6543 10.7479L29.4026 10.9856L28.4686 14.1212L26.6578 16.2576L24.7147 17.8344L24.6129 20.9881L26.2 21.7511L25.9965 27.5397L24.5316 27.7024L21.5406 26.8581L18.8651 24.2537L18.3361 23.5009L13.6971 23.6738L10.9096 26.3698L10.5434 26.8886L5.45236 28.1993L6.16398 21.6746L6.95623 21.1794V17.6539L4.04471 14.8216L3.17324 11.6724L11.2938 10.2463Z" fill="#C9C2B3"/>
<path id="Vector" d="M16 2.68001V2.66668" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_2" d="M12 25.3467V25.3333" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_3" d="M20 25.3467V25.3333" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_4" d="M5.33333 16.0133V16" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_5" d="M26.6667 16.0133V16" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_6" d="M5.33333 22.6667V28H9.33333" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_7" d="M26.6667 22.6667V28H22.6667" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_8" d="M14.6667 22.6667H17.3333" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_9" d="M10.6667 10.6667H2.66667V13.3333" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_10" d="M21.3333 10.6667H29.3333V13.3333" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_11" d="M24 18.6667V20" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_12" d="M8 18.6667V20" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_13" d="M18.6667 5.33333V8" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
<path id="Vector_14" d="M13.3333 5.33333V8" stroke-width="2.66667" stroke-linecap="square" stroke="#C9C2B3"/>
</g>
</svg>
"""

## Pixel icons, 10x10 grid of 2x2 blocks (top-left corners), traced from the Figma frames.
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
