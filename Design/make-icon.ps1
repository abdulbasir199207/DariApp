# Erzeugt das ZARA-App-Icon (schwarze Katze, eigener Entwurf) als PNG ohne Alpha-Kanal.
#   powershell -ExecutionPolicy Bypass -File Design\make-icon.ps1
# Ausgabe: Design\zara-icon-1024.png, Design\zara-icon-180.png (PWA/Apple-Touch-Icon)
Add-Type -AssemblyName System.Drawing

$outDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$S = 1024
$bmp = New-Object System.Drawing.Bitmap($S, $S, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

function C($hex, $a = 255) { $c = [System.Drawing.ColorTranslator]::FromHtml($hex); [System.Drawing.Color]::FromArgb($a, $c.R, $c.G, $c.B) }

# Hintergrund: Salbei -> Türkis (Farben der App-Palette)
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Point(0, 0)), (New-Object System.Drawing.Point($S, $S)), (C '#8FA98C'), (C '#7FC5C0'))
$g.FillRectangle($bg, 0, 0, $S, $S)
# sanfter Lichtfleck oben links
$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(-200, -250, 900, 900)
$pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($glow)
$pg.CenterColor = (C '#FFFFFF' 70); $pg.SurroundColors = @((C '#FFFFFF' 0))
$g.FillPath($pg, $glow)

# SVG-Koordinaten (0..100) -> Leinwand
$sc = 9.6
function P($x, $y) { New-Object System.Drawing.PointF([single](512 + ($x - 50) * $sc), [single](512 + ($y - 48) * $sc)) }
function Poly($brush, $pts) { $arr = [System.Drawing.PointF[]]($pts | ForEach-Object { P $_[0] $_[1] }); $g.FillPolygon($brush, $arr) }
function Ell($brush, $cx, $cy, $rx, $ry) { $a = P ($cx - $rx) ($cy - $ry); $g.FillEllipse($brush, $a.X, $a.Y, [single](2 * $rx * $sc), [single](2 * $ry * $sc)) }
function Quad($pen, $x0, $y0, $cx, $cy, $x1, $y1) {
  $p0 = P $x0 $y0; $pc = P $cx $cy; $p1 = P $x1 $y1
  $c1 = New-Object System.Drawing.PointF([single]($p0.X + 2 / 3 * ($pc.X - $p0.X)), [single]($p0.Y + 2 / 3 * ($pc.Y - $p0.Y)))
  $c2 = New-Object System.Drawing.PointF([single]($p1.X + 2 / 3 * ($pc.X - $p1.X)), [single]($p1.Y + 2 / 3 * ($pc.Y - $p1.Y)))
  $g.DrawBezier($pen, $p0, $c1, $c2, $p1)
}

# weicher Schatten unter dem Kopf
$shadow = New-Object System.Drawing.SolidBrush((C '#000000' 38))
Ell $shadow 50 61 33 27

$black = New-Object System.Drawing.SolidBrush((C '#16181B'))
Poly $black @(@(20, 46), @(22, 14), @(46, 31))
Poly $black @(@(80, 46), @(78, 14), @(54, 31))
$ear = New-Object System.Drawing.SolidBrush((C '#C77B58' 220))
Poly $ear @(@(26, 40), @(27, 22), @(40, 32))
Poly $ear @(@(74, 40), @(73, 22), @(60, 32))

# Kopf mit leichtem Verlauf
$a = P 18 30; $headRect = New-Object System.Drawing.RectangleF($a.X, $a.Y, [single](64 * $sc), [single](54 * $sc))
$headBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($headRect, (C '#2A2E33'), (C '#101215'), 90)
Ell $headBrush 50 57 32 27

# Augen
$eye = New-Object System.Drawing.SolidBrush((C '#E3D27B'))
Ell $eye 39 54 7 7.6; Ell $eye 61 54 7 7.6
$pupil = New-Object System.Drawing.SolidBrush((C '#0B0C0E'))
Ell $pupil 39 54 2 5.6; Ell $pupil 61 54 2 5.6
$shine = New-Object System.Drawing.SolidBrush((C '#FFFFFF' 235))
Ell $shine 41 51 1.6 1.6; Ell $shine 63 51 1.6 1.6

# Nase, Mund, Schnurrhaare
$nose = New-Object System.Drawing.SolidBrush((C '#C77B58'))
Poly $nose @(@(46.5, 63), @(53.5, 63), @(50, 67.5))
$pen = New-Object System.Drawing.Pen((C '#7B858D'), [single](1.7 * $sc)); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
Quad $pen 50 67.5 46.5 72.5 42 70.7
Quad $pen 50 67.5 53.5 72.5 58 70.7
$wp = New-Object System.Drawing.Pen((C '#AAB3BA' 230), [single](1.2 * $sc)); $wp.StartCap = 'Round'; $wp.EndCap = 'Round'
foreach ($l in @(@(30, 64, 12, 61), @(30, 68, 13, 71), @(70, 64, 88, 61), @(70, 68, 87, 71))) {
  $p0 = P $l[0] $l[1]; $p1 = P $l[2] $l[3]; $g.DrawLine($wp, $p0, $p1)
}

$g.Dispose()
$bmp.Save((Join-Path $outDir 'zara-icon-1024.png'), [System.Drawing.Imaging.ImageFormat]::Png)

# kleine Variante für Apple-Touch-Icon / PWA
$small = New-Object System.Drawing.Bitmap(180, 180, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g2 = [System.Drawing.Graphics]::FromImage($small)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.DrawImage($bmp, 0, 0, 180, 180); $g2.Dispose()
$small.Save((Join-Path $outDir 'zara-icon-180.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose(); $small.Dispose()
Write-Output 'Icons geschrieben.'
