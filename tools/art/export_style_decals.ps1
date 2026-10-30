# Mechanical atlas slicing and sizing only; artwork comes from image_gen.
param([string]$SourceDir = 'assets/art/decals/style_sources_v2', [string]$OutputDir = 'assets/art/decals', [string[]]$Sets = @('dojo_wood_v2','gym_rubber_v1','courtyard_stone_v1','rooftop_concrete_v1','temple_stone_v1'))
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$records = @()
function Export-Cell($Image, $Region, $Path, $Width, $Height) {
    $minX=$Region.Right; $maxX=$Region.Left; $minY=$Region.Bottom; $maxY=$Region.Top
    for ($y=$Region.Top; $y -lt $Region.Bottom; $y++) {
        for ($x=$Region.Left; $x -lt $Region.Right; $x++) {
            if ($Image.GetPixel($x,$y).A -ge 32) {
                $minX=[Math]::Min($minX,$x); $maxX=[Math]::Max($maxX,$x)
                $minY=[Math]::Min($minY,$y); $maxY=[Math]::Max($maxY,$y)
            }
        }
    }
    if ($minX -ge $maxX -or $minY -ge $maxY) { throw "Empty generated sprite: $Path" }
    $minX=[Math]::Max($Region.Left,$minX-4); $minY=[Math]::Max($Region.Top,$minY-4)
    $maxX=[Math]::Min($Region.Right-1,$maxX+4); $maxY=[Math]::Min($Region.Bottom-1,$maxY+4)
    $src=[System.Drawing.Rectangle]::new($minX,$minY,$maxX-$minX+1,$maxY-$minY+1)
    $dst=[System.Drawing.Bitmap]::new($Width,$Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g=[System.Drawing.Graphics]::FromImage($dst)
    try {
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.CompositingMode=[System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $scale=[Math]::Min(($Width-32)/$src.Width,($Height-24)/$src.Height)
        $w=[int][Math]::Round($src.Width*$scale); $h=[int][Math]::Round($src.Height*$scale)
        $target=[System.Drawing.Rectangle]::new([int](($Width-$w)/2),[int](($Height-$h)/2),$w,$h)
        $g.DrawImage($Image,$target,$src,[System.Drawing.GraphicsUnit]::Pixel)
        $dst.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $g.Dispose(); $dst.Dispose() }
    return @{file=$Path;source_rect=@($src.X,$src.Y,$src.Width,$src.Height);width=$Width;height=$Height}
}
foreach ($id in $Sets) {
    $folder=Join-Path $OutputDir $id
    New-Item -ItemType Directory -Force $folder | Out-Null
    $floorSource=if($id -eq 'dojo_wood_v2') {'wood_floor.png'} else {"$id.png"}
    $image=[System.Drawing.Bitmap]::new((Resolve-Path (Join-Path $SourceDir $floorSource)).Path)
    try {
        $split=if($id -eq 'dojo_wood_v2') {$image.Width} else {[int]($image.Width*1100/1536)}
        for($row=0;$row -lt 4;$row++) {
            $top=[int][Math]::Floor($image.Height*$row/4)
            $bottom=[int][Math]::Floor($image.Height*($row+1)/4)
            $name=if($row -eq 3) {'floor_scuff_light.png'} else {'floor_impact_{0:00}.png' -f ($row+1)}
            $records += Export-Cell $image ([System.Drawing.Rectangle]::new(0,$top,$split,$bottom-$top)) (Join-Path $folder $name) 1024 256
        }
        if($id -ne 'dojo_wood_v2') {
            for($row=0;$row -lt 3;$row++) {
                $top=[int][Math]::Floor($image.Height*$row/4)
                $bottom=if($row -eq 2) {$image.Height} else {[int][Math]::Floor($image.Height*($row+1)/4)}
                $records += Export-Cell $image ([System.Drawing.Rectangle]::new($split,$top,$image.Width-$split,$bottom-$top)) (Join-Path $folder ('wall_impact_{0:00}.png' -f ($row+1))) 512 1024
            }
        }
    } finally { $image.Dispose() }
    if($id -eq 'dojo_wood_v2') {
        $image=[System.Drawing.Bitmap]::new((Resolve-Path (Join-Path $SourceDir 'wood_wall.png')).Path)
        try {
            for($col=0;$col -lt 3;$col++) {
                $left=[int][Math]::Floor($image.Width*$col/3); $right=[int][Math]::Floor($image.Width*($col+1)/3)
                $records += Export-Cell $image ([System.Drawing.Rectangle]::new($left,0,$right-$left,$image.Height)) (Join-Path $folder ('wall_impact_{0:00}.png' -f ($col+1))) 512 1024
            }
        } finally { $image.Dispose() }
    }
    $metadata=@{floor_width_base=110;floor_width_power=28;floor_aspect=0.18;floor_opacity=0.8;wall_height_base=60;wall_height_power=22;wall_aspect=0.32;wall_opacity=0.8;scuff_aspect=0.12;scuff_opacity=0.6;clip_floor=$true}
    [IO.File]::WriteAllText((Join-Path (Resolve-Path $folder) 'art.json'),($metadata|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
}
[IO.File]::WriteAllText((Join-Path (Resolve-Path $SourceDir) 'exports.json'),($records|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
