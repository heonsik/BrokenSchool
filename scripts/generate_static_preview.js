const fs = require("fs");
const path = require("path");

const children = [];

const rgb = (r, g, b) => [r / 255, g / 255, b / 255];

function part(name, size, position, color, options = {}) {
  const properties = {
    Anchored: true,
    Size: size,
    Position: position,
    Color: color,
  };

  if (options.material) properties.Material = options.material;
  if (options.transparency !== undefined) properties.Transparency = options.transparency;
  if (options.canCollide !== undefined) properties.CanCollide = options.canCollide;
  if (options.canTouch !== undefined) properties.CanTouch = options.canTouch;
  if (options.shape) properties.Shape = options.shape;
  if (options.neutral !== undefined) properties.Neutral = options.neutral;
  if (options.allowTeamChangeOnTouch !== undefined) {
    properties.AllowTeamChangeOnTouch = options.allowTeamChangeOnTouch;
  }

  children.push({
    name,
    className: options.className || "Part",
    properties,
  });
}

function wall(name, position, size, color = rgb(112, 116, 122)) {
  part(name, size, position, color, { material: "Concrete" });
  if (size[1] >= 8) {
    part(`${name}_LowerTrim`, [size[0], 0.35, size[2]], [position[0], 1.45, position[2]], rgb(56, 61, 70));
  }
}

function floor(name, size, position, color, material = "Concrete") {
  part(name, [size[0], 0.18, size[1]], [position[0], 0.62, position[1]], color, { material });
}

function ceiling(name, size, position) {
  part(name, [size[0], 0.28, size[1]], [position[0], 11.6, position[1]], rgb(176, 179, 185));
}

function lightPanel(name, x, z, w = 10, d = 2) {
  part(name, [w, 0.18, d], [x, 11.25, z], rgb(255, 236, 178), {
    material: "Neon",
    canCollide: false,
  });
}

function window(name, x, z, side, count = 1) {
  for (let i = 0; i < count; i += 1) {
    const offset = (i - (count - 1) / 2) * 9;
    const pos = side === "north" || side === "south"
      ? [x + offset, 6.6, z]
      : [x, 6.6, z + offset];
    const size = side === "north" || side === "south" ? [6.5, 4.2, 0.22] : [0.22, 4.2, 6.5];
    part(`${name}_Glass_${i}`, size, pos, rgb(152, 202, 226), {
      material: "Glass",
      transparency: 0.38,
      canCollide: false,
    });
    const plankSize = side === "north" || side === "south" ? [7.2, 0.32, 0.28] : [0.28, 0.32, 7.2];
    part(`${name}_BoardA_${i}`, plankSize, [pos[0], 6.4, pos[2]], rgb(92, 58, 34), { material: "Wood" });
    part(`${name}_BoardB_${i}`, plankSize, [pos[0], 8.0, pos[2]], rgb(78, 49, 31), { material: "Wood" });
  }
}

function door(name, x, z, side, color = rgb(98, 60, 35)) {
  const size = side === "north" || side === "south" ? [5, 7, 0.35] : [0.35, 7, 5];
  part(name, size, [x, 4, z], color, { material: "Wood", canCollide: false });
  const frameSize = side === "north" || side === "south" ? [6, 7.6, 0.42] : [0.42, 7.6, 6];
  part(`${name}_Frame`, frameSize, [x, 4.1, z], rgb(48, 52, 60), { material: "Metal", transparency: 0.25 });
}

function roomShell(name, center, size, color, options = {}) {
  const [x, z] = center;
  const [w, d] = size;
  floor(`${name}_Floor`, [w, d], [x, z], color, options.floorMaterial || "CeramicTiles");
  ceiling(`${name}_Ceiling`, [w, d], [x, z]);

  const northY = z + d / 2;
  const southY = z - d / 2;
  const westX = x - w / 2;
  const eastX = x + w / 2;
  const doorSide = options.doorSide || "south";

  if (doorSide === "south") {
    wall(`${name}_SouthWall_L`, [x - w * 0.28, 6, southY], [w * 0.44, 12, 1.4]);
    wall(`${name}_SouthWall_R`, [x + w * 0.28, 6, southY], [w * 0.44, 12, 1.4]);
    door(`${name}_Door`, x, southY - 0.1, "south", options.doorColor);
  } else {
    wall(`${name}_SouthWall`, [x, 6, southY], [w, 12, 1.4]);
  }

  if (doorSide === "north") {
    wall(`${name}_NorthWall_L`, [x - w * 0.28, 6, northY], [w * 0.44, 12, 1.4]);
    wall(`${name}_NorthWall_R`, [x + w * 0.28, 6, northY], [w * 0.44, 12, 1.4]);
    door(`${name}_Door`, x, northY + 0.1, "north", options.doorColor);
  } else {
    wall(`${name}_NorthWall`, [x, 6, northY], [w, 12, 1.4]);
  }

  wall(`${name}_WestWall`, [westX, 6, z], [1.4, 12, d]);
  wall(`${name}_EastWall`, [eastX, 6, z], [1.4, 12, d]);
  window(`${name}_Windows`, x, northY + 0.05, "north", Math.max(1, Math.floor(w / 18)));

  for (let i = 0; i < Math.max(1, Math.floor(w / 24)); i += 1) {
    lightPanel(`${name}_CeilingLight_${i}`, x - w / 4 + i * 24, z, 8, 3);
  }
}

function desk(name, x, z) {
  part(`${name}_Top`, [4.8, 0.45, 3], [x, 1.55, z], rgb(132, 82, 45), { material: "Wood" });
  part(`${name}_LegA`, [0.35, 1.4, 0.35], [x - 1.9, 0.85, z - 1.1], rgb(78, 50, 35), { material: "Wood" });
  part(`${name}_LegB`, [0.35, 1.4, 0.35], [x + 1.9, 0.85, z + 1.1], rgb(78, 50, 35), { material: "Wood" });
}

function chair(name, x, z) {
  part(`${name}_Seat`, [2.2, 0.35, 2.1], [x, 1.15, z], rgb(58, 88, 128), { material: "Wood" });
  part(`${name}_Back`, [2.2, 2.1, 0.28], [x, 2.2, z + 1.05], rgb(58, 88, 128), { material: "Wood" });
}

function classroomInterior(name, x, z, cols = 3, rows = 3) {
  part(`${name}_Blackboard`, [16, 4.6, 0.24], [x, 5.8, z + 17.3], rgb(22, 72, 45));
  part(`${name}_ChalkTray`, [16, 0.18, 0.55], [x, 3.35, z + 17.0], rgb(210, 210, 190));
  for (let row = 0; row < rows; row += 1) {
    for (let col = 0; col < cols; col += 1) {
      const dx = x - (cols - 1) * 7 + col * 14;
      const dz = z - 8 + row * 7;
      desk(`${name}_Desk_${row}_${col}`, dx, dz);
      chair(`${name}_Chair_${row}_${col}`, dx, dz - 3);
    }
  }
}

function locker(name, x, z) {
  part(`${name}_Body`, [3, 7, 2.1], [x, 4, z], rgb(36, 70, 92), { material: "Metal" });
  part(`${name}_Door`, [2.55, 5.7, 0.16], [x, 4, z - 1.14], rgb(46, 96, 122), { material: "Metal" });
  part(`${name}_Vent`, [2, 0.12, 0.18], [x, 5.8, z - 1.25], rgb(20, 35, 46), { material: "Metal" });
}

function lockerRow(prefix, startX, z, count, spacing = 4.1) {
  for (let i = 0; i < count; i += 1) locker(`${prefix}_${i}`, startX + i * spacing, z);
}

function shelf(name, x, z) {
  part(`${name}_Case`, [2.1, 7, 10], [x, 4.1, z], rgb(78, 48, 32), { material: "Wood" });
  part(`${name}_BooksA`, [2.25, 1.0, 8.6], [x, 5.9, z], rgb(90, 118, 165));
  part(`${name}_BooksB`, [2.25, 1.0, 8.6], [x, 3.6, z], rgb(154, 78, 76));
}

function cafeteriaTable(name, x, z) {
  part(`${name}_Top`, [9, 0.45, 2.5], [x, 1.45, z], rgb(118, 78, 48), { material: "Wood" });
  part(`${name}_BenchA`, [9, 0.35, 0.85], [x, 1.05, z - 2.4], rgb(72, 83, 94), { material: "Metal" });
  part(`${name}_BenchB`, [9, 0.35, 0.85], [x, 1.05, z + 2.4], rgb(72, 83, 94), { material: "Metal" });
}

function debris(name, x, z, color = rgb(86, 89, 94)) {
  part(`${name}_SlabA`, [4, 0.25, 2], [x, 0.95, z], color, { material: "Concrete" });
  part(`${name}_SlabB`, [2, 0.2, 1.2], [x + 3, 0.9, z - 1.5], rgb(68, 70, 75), { material: "Concrete" });
  part(`${name}_Rebar`, [0.28, 0.28, 5], [x - 1.5, 1.15, z + 1.2], rgb(40, 42, 45), { material: "Metal" });
}

function crack(name, x, z, length, horizontal = true) {
  part(name, horizontal ? [length, 0.08, 0.28] : [0.28, 0.08, length], [x, 0.82, z], rgb(22, 22, 25), {
    material: "SmoothPlastic",
    canCollide: false,
  });
}

function boardedHole(name, x, z, side = "north") {
  const glassSize = side === "north" || side === "south" ? [10, 5.5, 0.22] : [0.22, 5.5, 10];
  part(`${name}_DarkGap`, glassSize, [x, 6.5, z], rgb(18, 20, 24), { transparency: 0.15, canCollide: false });
  const plankSize = side === "north" || side === "south" ? [11, 0.38, 0.3] : [0.3, 0.38, 11];
  part(`${name}_PlankA`, plankSize, [x, 5.7, z], rgb(92, 58, 34), { material: "Wood" });
  part(`${name}_PlankB`, plankSize, [x, 7.3, z], rgb(70, 45, 30), { material: "Wood" });
}

function landmark(name, x, z, color) {
  part(name, [3.5, 12, 3.5], [x, 6.5, z], color, { material: "Neon", transparency: 0.35, canCollide: false });
}

function lampPost(name, x, z, color = rgb(255, 225, 160)) {
  part(`${name}_Post`, [0.55, 9, 0.55], [x, 5.1, z], rgb(45, 49, 55), { material: "Metal" });
  part(`${name}_Head`, [2.1, 0.9, 2.1], [x, 9.9, z], color, { material: "Neon", canCollide: false });
}

function barricade(name, x, z) {
  part(`${name}_A`, [8, 1.0, 0.65], [x, 3.5, z], rgb(220, 175, 60), { material: "Wood" });
  part(`${name}_B`, [8, 1.0, 0.65], [x, 2.2, z], rgb(45, 45, 48), { material: "Wood" });
  part(`${name}_LegA`, [0.55, 3.1, 0.55], [x - 3.6, 2.2, z], rgb(70, 45, 28), { material: "Wood" });
  part(`${name}_LegB`, [0.55, 3.1, 0.55], [x + 3.6, 2.2, z], rgb(70, 45, 28), { material: "Wood" });
}

function crates(name, x, z) {
  part(`${name}_Large`, [4.6, 3.6, 4.6], [x, 2.3, z], rgb(110, 78, 45), { material: "Wood" });
  part(`${name}_SmallA`, [3.2, 2.6, 3.2], [x + 4.2, 1.8, z + 1.1], rgb(126, 92, 54), { material: "Wood" });
  part(`${name}_SmallB`, [2.8, 2.2, 2.8], [x - 4.0, 1.6, z - 1.4], rgb(118, 84, 49), { material: "Wood" });
}

function bench(name, x, z) {
  part(`${name}_Seat`, [8, 0.55, 2], [x, 2.9, z], rgb(96, 68, 42), { material: "Wood" });
  part(`${name}_Back`, [8, 2.1, 0.45], [x, 3.8, z + 1.1], rgb(82, 60, 40), { material: "Wood" });
  part(`${name}_LegA`, [0.5, 1.8, 0.5], [x - 3.2, 1.9, z - 0.4], rgb(45, 45, 48), { material: "Metal" });
  part(`${name}_LegB`, [0.5, 1.8, 0.5], [x + 3.2, 1.9, z - 0.4], rgb(45, 45, 48), { material: "Metal" });
}

function tree(name, x, z, scale = 1) {
  part(`${name}_Trunk`, [1.4 * scale, 6 * scale, 1.4 * scale], [x, 3.6 * scale, z], rgb(86, 52, 28), { material: "Wood" });
  part(`${name}_Leaves`, [6 * scale, 6 * scale, 6 * scale], [x, 8 * scale, z], rgb(38, 108, 64), {
    material: "Grass",
    shape: "Ball",
  });
}

function scienceLab(name, x, z) {
  classroomInterior(name, x, z, 3, 2);
  for (let i = 0; i < 4; i += 1) {
    part(`${name}_LabBench_${i}`, [6, 0.35, 2.4], [x - 18 + i * 12, 1.6, z - 1], rgb(28, 30, 34));
    part(`${name}_Flask_${i}`, [0.6, 0.9, 0.6], [x - 18 + i * 12, 2.25, z - 1], rgb(90, 180, 255), {
      material: "Glass",
      transparency: 0.35,
    });
  }
  part(`${name}_SkeletonBody`, [1, 5.5, 1], [x + 23, 3.75, z + 12], rgb(228, 215, 190));
  part(`${name}_SkeletonHead`, [1.2, 1.2, 1.2], [x + 23, 7.1, z + 12], rgb(228, 215, 190), { shape: "Ball" });
}

function musicRoom(name, x, z) {
  classroomInterior(name, x, z, 2, 2);
  part(`${name}_PianoBody`, [6, 4.2, 2.4], [x - 20, 3.1, z + 13], rgb(18, 18, 20));
  part(`${name}_PianoKeys`, [5, 0.35, 0.9], [x - 20, 1.7, z + 11.8], rgb(245, 245, 245));
  part(`${name}_DrumBase`, [4.2, 1.8, 4.2], [x + 17, 1.5, z + 11], rgb(160, 45, 45));
  part(`${name}_Cymbal`, [2.6, 0.1, 2.6], [x + 17, 3.5, z + 11], rgb(190, 175, 35), { material: "Metal" });
}

function artRoom(name, x, z) {
  classroomInterior(name, x, z, 2, 2);
  for (let i = 0; i < 4; i += 1) {
    part(`${name}_Easel_${i}`, [0.35, 4.2, 0.35], [x - 15 + i * 10, 3, z - 2], rgb(104, 66, 32), { material: "Wood" });
    part(`${name}_Canvas_${i}`, [3.2, 3.8, 0.14], [x - 15 + i * 10, 4.3, z - 2], rgb(240, 233, 216));
  }
  part(`${name}_PaintSplashRed`, [3.5, 0.06, 2.8], [x + 8, 0.86, z - 8], rgb(210, 55, 55), { material: "Neon", canCollide: false });
  part(`${name}_PaintSplashBlue`, [3, 0.06, 2.8], [x - 8, 0.86, z + 5], rgb(58, 105, 210), { material: "Neon", canCollide: false });
}

function broadcastRoom(name, x, z) {
  part(`${name}_Console`, [20, 0.9, 3.5], [x, 1.7, z + 8], rgb(18, 20, 28));
  part(`${name}_ConsoleLEDs`, [18, 0.18, 2], [x, 2.35, z + 8], rgb(0, 180, 255), { material: "Neon", canCollide: false });
  for (let i = 0; i < 3; i += 1) {
    part(`${name}_Monitor_${i}`, [4, 2.8, 0.22], [x - 8 + i * 8, 4.1, z + 12], rgb(12, 14, 18));
    part(`${name}_MonitorGlow_${i}`, [3.4, 2.2, 0.16], [x - 8 + i * 8, 4.1, z + 11.8], rgb(60, 150, 240), { material: "Neon" });
  }
  part(`${name}_CameraTripod`, [0.35, 3.8, 0.35], [x - 21, 2.5, z - 3], rgb(38, 38, 40), { material: "Metal" });
  part(`${name}_CameraBody`, [1.5, 1.1, 2.2], [x - 21, 5, z - 3], rgb(22, 22, 25));
}

function healthRoom(name, x, z) {
  for (let i = 0; i < 3; i += 1) {
    part(`${name}_MedBed_${i}`, [4.5, 0.55, 9], [x - 16 + i * 16, 1.8, z + 4], rgb(242, 242, 248));
    part(`${name}_Pillow_${i}`, [3, 0.45, 2], [x - 16 + i * 16, 2.35, z + 8.2], rgb(248, 248, 252));
    part(`${name}_IVPole_${i}`, [0.25, 4.5, 0.25], [x - 16 + i * 16 + 2.5, 3, z + 7], rgb(165, 175, 185), { material: "Metal" });
  }
  part(`${name}_RedCrossH`, [5.5, 1.2, 0.15], [x, 8.5, z + 17.5], rgb(220, 35, 35), { material: "Neon", canCollide: false });
  part(`${name}_RedCrossV`, [1.2, 5.5, 0.15], [x, 8.5, z + 17.4], rgb(220, 35, 35), { material: "Neon", canCollide: false });
}

function createBrokenSchoolWorld() {
  floor("SchoolFloor", [700, 460], [0, 0], rgb(82, 88, 96), "Concrete");

  floor("MainCorridor_Floor", [640, 18], [0, 0], rgb(64, 78, 96), "Slate");
  floor("NorthWing_Corridor", [520, 16], [20, 118], rgb(58, 76, 98), "Slate");
  floor("SouthWing_Corridor", [520, 16], [20, -142], rgb(58, 76, 98), "Slate");
  floor("WestConnector_Floor", [16, 250], [-230, -12], rgb(58, 76, 98), "Slate");
  floor("EastConnector_Floor", [16, 250], [250, -12], rgb(58, 76, 98), "Slate");

  wall("Outer_NorthWall", [0, 6, 230], [700, 12, 2]);
  wall("Outer_SouthWall", [0, 6, -230], [700, 12, 2]);
  wall("Outer_WestWall", [-350, 6, 0], [2, 12, 460]);
  wall("Outer_EastWallTop", [350, 6, 125], [2, 12, 210]);
  wall("Outer_EastWallBottom", [350, 6, -125], [2, 12, 210]);
  window("Outer_NorthWindows", 0, 229.3, "north", 15);
  window("Outer_SouthWindows", 0, -229.3, "south", 15);

  ceiling("MainCorridor_Ceiling", [640, 18], [0, 0]);
  ceiling("NorthWing_Ceiling", [520, 16], [20, 118]);
  ceiling("SouthWing_Ceiling", [520, 16], [20, -142]);
  for (let i = 0; i < 12; i += 1) lightPanel(`MainCorridor_Light_${i}`, -275 + i * 50, 0, 10, 2.5);
  for (let i = 0; i < 8; i += 1) lightPanel(`NorthCorridor_Light_${i}`, -190 + i * 55, 118, 9, 2.5);
  for (let i = 0; i < 8; i += 1) lightPanel(`SouthCorridor_Light_${i}`, -190 + i * 55, -142, 9, 2.5);

  roomShell("StartClassroom", [-52, 25], [38, 30], rgb(82, 102, 140), { doorSide: "south", doorColor: rgb(70, 115, 200) });
  classroomInterior("StartClassroom", -52, 25, 2, 2);
  roomShell("Library", [-8, 33], [36, 28], rgb(78, 70, 102), { doorSide: "south", floorMaterial: "WoodPlanks" });
  [-16, -8, 0, 8].forEach((x, i) => shelf(`LibraryShelf_${i}`, x, 33));
  shelf("LibraryShelf_SideA", -20, 38);
  shelf("LibraryShelf_SideB", 5, 38);

  roomShell("ClassroomB", [28, 33], [36, 28], rgb(118, 88, 62), { doorSide: "south" });
  classroomInterior("ClassroomB", 28, 33, 2, 2);
  roomShell("Cafeteria", [24, -33], [46, 34], rgb(112, 88, 68), { doorSide: "north" });
  [-2, 12, 26, 40].forEach((x, i) => cafeteriaTable(`CafeteriaTable_${i}`, x, -33));
  part("VendingMachine", [3.2, 6, 2], [42, 3.4, -45], rgb(210, 45, 65));
  part("VendingMachineScreen", [2, 2, 0.18], [42, 4.5, -46.05], rgb(80, 220, 255), { material: "Neon" });

  roomShell("ScienceRoom", [-185, 138], [58, 40], rgb(52, 105, 88), { doorSide: "south" });
  scienceLab("ScienceRoom", -185, 138);
  roomShell("MusicRoom", [-95, 138], [58, 40], rgb(92, 66, 120), { doorSide: "south" });
  musicRoom("MusicRoom", -95, 138);
  roomShell("ArtRoom", [125, 138], [58, 40], rgb(130, 86, 62), { doorSide: "south" });
  artRoom("ArtRoom", 125, 138);
  roomShell("BroadcastRoom", [225, 112], [58, 38], rgb(64, 104, 128), { doorSide: "south" });
  broadcastRoom("BroadcastRoom", 225, 112);

  roomShell("HealthRoom", [-165, -146], [58, 40], rgb(126, 78, 96), { doorSide: "north" });
  healthRoom("HealthRoom", -165, -146);
  roomShell("GeneratorRoom", [230, -146], [58, 42], rgb(58, 96, 120), { doorSide: "north", floorMaterial: "Metal" });
  part("EmergencyGenerator", [6, 4, 4], [230, 2.2, -145], rgb(65, 170, 230), { material: "Metal" });
  part("GeneratorCoil", [4.6, 1.1, 1.1], [230, 3.7, -147.2], rgb(120, 230, 255), { material: "Neon", canCollide: false });
  part("BrokenPipe_A", [36, 0.7, 0.7], [230, 8.5, -165], rgb(80, 88, 92), { material: "Metal" });
  part("BrokenPipe_B", [0.7, 0.7, 28], [255, 8.3, -145], rgb(80, 88, 92), { material: "Metal" });

  floor("GymFloor", [92, 62], [-260, -146], rgb(82, 88, 98), "WoodPlanks");
  wall("Gym_NorthWall", [-260, 6, -115], [92, 12, 2]);
  wall("Gym_SouthWall", [-260, 6, -177], [92, 12, 2]);
  wall("Gym_WestWall", [-306, 6, -146], [2, 12, 62]);
  wall("Gym_EastWall", [-214, 6, -146], [2, 12, 62]);
  ceiling("Gym_Ceiling", [92, 62], [-260, -146]);
  for (let i = 0; i < 4; i += 1) part(`GymBleacher_${i}`, [34, 1, 4], [-290, 1 + i * 1.1, -169 + i * 4], rgb(82, 92, 110), { material: "Metal" });
  part("BasketballCourtLine", [62, 0.1, 2], [-260, 1, -146], rgb(255, 235, 130), { material: "Neon", canCollide: false });
  part("BasketballHoop_A", [6, 6, 0.5], [-300, 6, -146], rgb(255, 135, 45), { material: "Neon" });
  part("BasketballHoop_B", [6, 6, 0.5], [-220, 6, -146], rgb(255, 135, 45), { material: "Neon" });

  floor("OutdoorYard", [120, 70], [115, -35], rgb(58, 120, 66), "Grass");
  tree("YardTree_A", 80, -50, 1.1);
  tree("YardTree_B", 130, -70, 1);
  tree("YardTree_C", 160, -20, 1.1);
  part("FallenFence_A", [34, 1.2, 0.8], [115, 1.4, -70], rgb(80, 72, 58), { material: "Wood" });

  lockerRow("MainLockerLeft", -44, -7, 3);
  lockerRow("MainLockerRight", 12, 9, 4);
  lockerRow("NorthLocker", -220, 124, 8);
  lockerRow("SouthLocker", -185, -149, 7);
  part("FallenLocker_NorthA", [7, 3, 2.2], [-78, 1.5, 119], rgb(35, 70, 95), { material: "Metal" });
  part("FallenLocker_SouthA", [7, 3, 2.2], [-55, 1.5, -141], rgb(35, 70, 95), { material: "Metal" });

  [
    [-18, 12], [72, -12], [-185, 106], [-95, 106],
    [125, 106], [225, 86], [-165, -168], [118, -158],
  ].forEach(([x, z], i) => bench(`HallBench_${i}`, x, z));

  [
    [-132, 18], [-76, -16], [72, 18], [170, -20], [-215, 102], [-112, 142],
    [168, 103], [245, 82], [-295, -118], [-210, -174], [84, -124], [250, -118],
  ].forEach(([x, z], i) => barricade(`Barricade_${i}`, x, z));

  [
    [-155, -28], [-18, 84], [68, -84], [210, 32],
    [-280, 126], [245, 150], [-116, -180], [185, -184],
  ].forEach(([x, z], i) => crates(`SupplyCrates_${i}`, x, z));

  [
    [65, -12], [95, -22], [130, -8], [165, -56], [68, -72], [148, -76],
    [-308, 164], [-286, 190], [292, 158], [318, 186], [-310, -188], [310, -190],
  ].forEach(([x, z], i) => tree(`CampusTree_${i}`, x, z, 0.9));

  [
    [-300, 0], [-230, 80], [-230, -80], [-120, 0], [0, 0], [120, 0],
    [250, 85], [250, -85], [305, 28], [-185, 120], [-40, 120], [125, 120],
    [-220, -145], [20, -145], [230, -145],
  ].forEach(([x, z], i) => lampPost(`EmergencyLamp_${i}`, x, z));

  landmark("StartWingLandmark", -52, 22, rgb(70, 135, 255));
  landmark("NorthWingLandmark", -185, 120, rgb(150, 95, 255));
  landmark("SouthWingLandmark", 135, -145, rgb(255, 150, 70));
  landmark("GymLandmark", -260, -145, rgb(255, 205, 70));
  landmark("ExitLandmark", 305, 0, rgb(80, 255, 130));

  [
    [-42, -2, 8, true], [18, 8, 10, true], [-120, 120, 12, true],
    [60, 122, 10, true], [-80, -142, 9, true], [80, -141, 11, true],
    [52, 40, 8, true], [-64, 5, 6, false],
  ].forEach(([x, z, len, horizontal], i) => crack(`FloorCrack_${i}`, x, z, len, horizontal));

  [
    [-18, -4], [24, 8], [44, -18], [-155, 118], [30, 122],
    [175, 119], [-80, -142], [80, -141],
  ].forEach(([x, z], i) => debris(`BrokenGlass_${i}`, x, z, rgb(58, 62, 68)));

  boardedHole("BrokenNorthWindow", -20, 230.2, "north");
  boardedHole("BrokenSouthWindow", 125, -230.2, "south");
  boardedHole("BrokenGymWall", -306.2, -164, "west");

  part("PlayerSpawn", [8, 1, 8], [-52, 2, 23], rgb(70, 115, 200), {
    material: "Neon",
    className: "SpawnLocation",
    neutral: true,
    allowTeamChangeOnTouch: false,
  });
  part("EscapeExit", [10, 8, 18], [305, 3, 0], rgb(70, 220, 130), {
    material: "Neon",
    transparency: 0.55,
    canCollide: false,
  });
  part("ExitLockBarrier", [8, 9, 12], [305, 3, 0], rgb(220, 65, 65), {
    material: "ForceField",
    transparency: 0.35,
  });
  part("VictoryPlatform", [20, 1, 20], [330, 0.5, 0], rgb(70, 170, 105), { material: "Grass" });

  part("Fuse1", [3.2, 3.2, 3.2], [-190, 2.4, 135], rgb(255, 220, 70), { material: "Neon", shape: "Ball", canCollide: false });
  part("Fuse2", [3.2, 3.2, 3.2], [135, 2.4, -155], rgb(255, 220, 70), { material: "Neon", shape: "Ball", canCollide: false });
  part("Fuse3", [3.2, 3.2, 3.2], [255, 2.4, 110], rgb(255, 220, 70), { material: "Neon", shape: "Ball", canCollide: false });
  part("FlashlightPickup", [3.2, 3.2, 3.2], [-55, 2.2, 29], rgb(220, 235, 255), { material: "Neon", shape: "Ball", canCollide: false });
  part("BoostDrinkPickup", [3.2, 3.2, 3.2], [95, 2.2, -122], rgb(255, 125, 55), { material: "Neon", shape: "Ball", canCollide: false });
  part("ShieldCharmPickup", [3.2, 3.2, 3.2], [-245, 2.2, 88], rgb(150, 105, 255), { material: "Neon", shape: "Ball", canCollide: false });

  part("GuideBody", [3, 4.2, 2.4], [-56, 3, 17], rgb(80, 125, 215), { shape: "Ball", canCollide: false });
  part("GuideEyeA", [0.55, 0.55, 0.2], [-56.55, 3.65, 15.82], rgb(245, 245, 245), { shape: "Ball", canCollide: false });
  part("GuideEyeB", [0.55, 0.55, 0.2], [-55.45, 3.65, 15.82], rgb(245, 245, 245), { shape: "Ball", canCollide: false });
  part("GuideSmile", [1.1, 0.18, 0.12], [-56, 2.65, 15.72], rgb(25, 25, 35), { canCollide: false });
}

createBrokenSchoolWorld();

const generatedDir = path.join(__dirname, "generated");
fs.mkdirSync(generatedDir, { recursive: true });
fs.writeFileSync(
  path.join(generatedDir, "BrokenSchoolWorld.model.json"),
  `${JSON.stringify({ className: "Model", children }, null, 2)}\n`,
);

console.log(`Wrote ${children.length} broken school parts to scripts/generated`);
