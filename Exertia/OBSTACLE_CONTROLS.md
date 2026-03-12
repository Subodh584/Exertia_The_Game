# Obstacle System Control Panel 🚧

This document contains all the variables you can modify to control obstacle generation, positioning, and size in your game.

## Location
All obstacle variables are in `GameViewController.swift` under the `// MARK: - Obstacle System` section (around line 170).

---

## 🎮 Obstacle Generation Controls

### Spawn Frequency
```swift
var obstacleSpawnEveryXSegments: Int = 3
```
- **What it does**: Spawns obstacles every X road segments
- **Default**: `3` (obstacle appears every 3 road_simple segments)
- **Tip**: Lower number = more frequent obstacles, higher = more sparse

### Minimum Distance Between Obstacles
```swift
var obstacleMinDistanceBetween: Float = 20.0
```
- **What it does**: Minimum Z-axis distance between consecutive obstacles
- **Default**: `20.0` units
- **Tip**: Prevents obstacles from spawning too close together

---

## 🎯 Pattern System (12 Patterns!)

Every obstacle spawn picks a **random enabled pattern**. Each pattern forces the player to take a specific action. No more boring "do nothing" moments!

### Pattern Enable/Disable
```swift
var p1_enabled:  Bool = true   // All-cubes jump
var p2_enabled:  Bool = true   // 2 cuboids left+center
var p3_enabled:  Bool = true   // 2 cuboids center+right
var p4_enabled:  Bool = true   // 2 cuboids left+right
var p5_enabled:  Bool = true   // 2 cuboids + cube right
var p6_enabled:  Bool = true   // cube left + 2 cuboids
var p7_enabled:  Bool = true   // cuboid-cube-cuboid
var p8_enabled:  Bool = true   // hover (dive)
var p9_enabled:  Bool = true   // single cube center (breather)
var p10_enabled: Bool = true   // cuboid + 2 cubes
var p11_enabled: Bool = true   // 2 cubes left+right
var p12_enabled: Bool = true   // hover + cube center
```
Set any to `false` to remove it from rotation.

---

## 🎮 Pattern Details & X-Offset Controls

Each pattern has its own X-offset variables so you can fine-tune exactly where each obstacle sits on the road.

### Pattern 1: All Cubes — MUST JUMP 🦘
Three cubes across all lanes. The only escape is jumping.
```swift
var p1_cubeLeftX:   Float = -3.5
var p1_cubeCenterX: Float =  1.0
var p1_cubeRightX:  Float =  5.5
```

### Pattern 2: 2 Cuboids Left+Center — DODGE RIGHT ➡️
Tall cuboids block left and center. Player must move to right lane.
```swift
var p2_cuboidLeftX:   Float = -6.8
var p2_cuboidCenterX: Float =  0.0
```

### Pattern 3: 2 Cuboids Center+Right — DODGE LEFT ⬅️
Tall cuboids block center and right. Player must move to left lane.
```swift
var p3_cuboidCenterX: Float =  0.0
var p3_cuboidRightX:  Float =  6.8
```

### Pattern 4: 2 Cuboids Left+Right — STAY CENTER 🎯
Tall cuboids on both sides. Player stays in center lane.
```swift
var p4_cuboidLeftX:  Float = -6.8
var p4_cuboidRightX: Float =  6.8
```

### Pattern 5: 2 Cuboids + Cube Right — DODGE RIGHT & JUMP ➡️🦘
Left and center blocked by cuboids (can't jump). Right lane has a cube (must jump it).
```swift
var p5_cuboidLeftX:   Float = -6.8
var p5_cuboidCenterX: Float =  0.0
var p5_cubeRightX:    Float =  5.5
```

### Pattern 6: Cube Left + 2 Cuboids — DODGE LEFT & JUMP ⬅️🦘
Center and right blocked by cuboids. Left lane has a cube (must jump it).
```swift
var p6_cubeLeftX:      Float = -3.5
var p6_cuboidCenterX:  Float =  0.0
var p6_cuboidRightX:   Float =  6.8
```

### Pattern 7: Cuboid-Cube-Cuboid — STAY CENTER & JUMP 🎯🦘
Cuboids on sides (can't pass), cube in center (must jump). The hardest combo!
```swift
var p7_cuboidLeftX:   Float = -6.8
var p7_cubeCenterX:   Float =  1.0
var p7_cuboidRightX:  Float =  6.8
```

### Pattern 8: Hover Platform — MUST DIVE 🏊
Platform stretches across all lanes. Player must dive under it.
```swift
var p8_hoverX: Float = 0.0
```

### Pattern 9: Single Cube Center — BREATHER 💤
Easy pattern. Jump or dodge. Gives the player a moment to breathe.
```swift
var p9_cubeCenterX: Float = 1.0
```

### Pattern 10: Cuboid Left + 2 Cubes — TRICKY 🧩
Cuboid blocks left. Center and right have cubes (jumpable). Multiple options!
```swift
var p10_cuboidLeftX:   Float = -6.8
var p10_cubeCenterX:   Float =  1.0
var p10_cubeRightX:    Float =  5.5
```

### Pattern 11: 2 Cubes Left+Right — CENTER OR JUMP 🎯🦘
Cubes on both sides. Stay center (safe) or jump over a side cube.
```swift
var p11_cubeLeftX:  Float = -3.5
var p11_cubeRightX: Float =  5.5
```

### Pattern 12: Hover + Cube Center — DIVE OR DODGE 🏊➡️
Hover platform overhead AND a cube in center. Dive under hover or dodge to sides.
```swift
var p12_hoverX:      Float = 0.0
var p12_cubeCenterX: Float = 1.0
```

---

## 📏 Obstacle Y-Positioning Controls (height above road)

```swift
var cubeYOffset: Float = 3.8           // Cube height above road
var cuboidYOffset: Float = 6.0         // Cuboid height above road
var hoverPlatformYOffset: Float = 6.0  // Hover platform height above road
```

---

## 📐 Obstacle Size Controls

### Cube Size (X, Y, Z)
```swift
var cubeSizeX: Float = 3.5
var cubeSizeY: Float = 3.5
var cubeSizeZ: Float = 6.8
```

### Cuboid Size (X, Y, Z)
```swift
var cuboidSizeX: Float = 7.0
var cuboidSizeY: Float = 7.0
var cuboidSizeZ: Float = 8.0
```

### Hover Platform Size (X, Y, Z)
```swift
var hoverPlatformSizeX: Float = 20.0
var hoverPlatformSizeY: Float = 5
var hoverPlatformSizeZ: Float = 15.0
```

---

## 🔄 Obstacle Rotation Controls (degrees)

```swift
var cubeRotationX/Y/Z: Float = 0
var cuboidRotationX/Y/Z: Float = 0
var hoverPlatformRotationX/Y/Z: Float = 0
```

---

## 🎬 How It Works

1. **Road Spawning**: When `RoadManager` spawns a new road, it notifies `GameViewController`
2. **Obstacle Check**: System checks if obstacle should spawn (based on `obstacleSpawnEveryXSegments`)
3. **Pattern Selection**: Random pattern chosen from all **enabled** patterns
4. **Obstacle Creation**: Each piece in the pattern is cloned from `Obstacles.usdz`
5. **Positioning**: Each piece placed at its pattern-specific X offset + road Y + type Y offset
6. **Cleanup**: Old obstacles removed when 50 units behind player

---

## 🔧 Quick Adjustments

### Make obstacles more frequent:
```swift
obstacleSpawnEveryXSegments = 2  // Every 2 road segments
```

### Only want jump + lane-change patterns (disable dive):
```swift
p8_enabled = false   // No hover
p12_enabled = false  // No hover+cube combo
```

### Only want the hardest patterns:
```swift
p9_enabled = false   // Remove breather
p11_enabled = false  // Remove easy 2-cubes
```

### Shift Pattern 1 cubes to look better:
```swift
p1_cubeLeftX   = -4.0   // Move left cube further left
p1_cubeCenterX =  0.5   // Move center cube slightly
p1_cubeRightX  =  5.0   // Move right cube slightly left
```

---

## 🐛 Debugging Tips

1. **Obstacles look misaligned?**
   - Tweak the `p#_...X` offset variables for that pattern
   - Each pattern's obstacles are independently adjustable

2. **Too many/few obstacles?**
   - Adjust `obstacleSpawnEveryXSegments`
   - Adjust `obstacleMinDistanceBetween`

3. **Want fewer pattern types?**
   - Set `p#_enabled = false` for patterns you don't want

4. **Obstacles too big/small?**
   - Adjust size variables (cubeSizeX/Y/Z, cuboidSizeX/Y/Z, etc.)

---

## 📝 Console Logs

Watch for these in the console:
```
✅ Obstacles template loaded successfully
🚧 Spawned cube obstacle at X=-3.5, Z=-123.45
🚧 Spawned cuboid obstacle at X=-6.8, Z=-234.56
🚧 Spawned hover obstacle at X=0.0, Z=-345.67
```
