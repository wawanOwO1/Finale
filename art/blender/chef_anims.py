"""Generate the chef animation set (ANIMATION_DESIGN.md) on a Mixamo-rigged GLB and export it for Godot.

Run (one character per Blender session, so node names stay identical between chefs):
    blender -b --factory-startup --python art/blender/chef_anims.py -- apis
    blender -b --factory-startup --python art/blender/chef_anims.py -- tony

Options after the character name:
    --sheet <png>   render a contact sheet of every clip to <png>
    --no-export     skip writing the .glb / .blend

Conventions (Blender world after glTF import): +X = character's left, -Y = front, +Z = up.
Pose ops per bone, applied in order, all expressed in the rest pose frame:
    ("X"|"Y"|"Z", deg)   rotate about a world axis (torso, head, hips)
    ("to", "DOWN"|"UP"|"FWD"|"BACK"|"IN"|"OUT", deg)
                         swing the bone's current direction toward that world direction (arms, legs)
    ("twist", deg)       roll around the bone's current direction
"""

import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FPS = 30
B = "mixamorig:"

# ---------------------------------------------------------------------------------------------
# Personality (ANIMATION_DESIGN.md §2, §4)
# ---------------------------------------------------------------------------------------------

STYLES = {
    "apis": {
        "tempo": {"idle": 1.0, "chop": 1.0, "busy": 1.0, "victory": 1.0, "lose": 1.0},
        "amp": 1.0,
        "base": {"Spine": [("X", 4)]},
    },
    "tony": {
        "tempo": {"idle": 1.2, "chop": 0.8, "busy": 1.15, "victory": 1.0, "lose": 1.0},
        "amp": 1.3,
        # Slouch with the belly pushed out: pelvis-up spine leans back, upper spine forward, head stays level.
        "base": {
            "Spine": [("X", -6)],
            "Spine2": [("X", 10)],
            "Neck": [("X", -4)],
            "LeftShoulder": [("to", "DOWN", 6)],
            "RightShoulder": [("to", "DOWN", 6)],
        },
    },
}

DIRS = {
    "DOWN": Vector((0, 0, -1)),
    "UP": Vector((0, 0, 1)),
    "FWD": Vector((0, -1, 0)),
    "BACK": Vector((0, 1, 0)),
}


# ---------------------------------------------------------------------------------------------
# Pose helpers
# ---------------------------------------------------------------------------------------------

def arm(side, down=0, fwd=0, out=0, elbow=10, twist=0, hand=0):
    """Ops for one arm. down/fwd/out swing the upper arm from the A-pose; elbow flexes the forearm."""
    s = "Left" if side == "L" else "Right"
    up_ops = []
    if down:
        up_ops.append(("to", "DOWN", down))
    if out:
        up_ops.append(("to", "OUT", out))
    if fwd:
        up_ops.append(("to", "FWD", fwd))
    if twist:
        up_ops.append(("twist", twist if side == "L" else -twist))
    return {
        s + "Arm": up_ops,
        s + "ForeArm": [("flex", elbow)] if elbow else [],
        s + "Hand": [("flex", hand)] if hand else [],
    }


def relaxed_arms(extra_down=0):
    p = {}
    p.update(arm("L", down=32 + extra_down, elbow=12))
    p.update(arm("R", down=32 + extra_down, elbow=12))
    return p


def merge(*dicts):
    out = {}
    for d in dicts:
        for k, v in d.items():
            out[k] = out.get(k, []) + list(v)
    return out


# ---------------------------------------------------------------------------------------------
# Clips. Each returns (frames, loop, keys); key = dict(f=frame, pose=ops, hips=(x,y,z) m, crouch=m, only=bool)
# Frames are authored for Apis tempo; the style tempo scales them.
# ---------------------------------------------------------------------------------------------

def clip_idle(c):
    tony = c == "tony"
    keys = []
    for i, f in enumerate([0, 15, 30, 45, 60]):
        breath = [0, 0.5, 1, 0.5, 0][i]          # inhale peaks at the middle
        sway = [0, 1, 0, -1, 0][i]               # head sway, quarter cycle offset
        pose = merge(
            {"Spine1": [("X", -3 * breath)], "Spine2": [("X", -2 * breath)],
             "Head": [("X", -2 * breath), ("Y", 3 * sway)],
             "LeftShoulder": [("to", "UP", 2 * breath)], "RightShoulder": [("to", "UP", 2 * breath)]},
            relaxed_arms(),
        )
        hips = (0, 0, -0.01 + 0.012 * breath)
        if tony:
            pose = merge(pose, {"Head": [("Y", -6)], "Hips": [("Y", 4)],
                                "LeftUpLeg": [("Y", -4)], "RightUpLeg": [("Y", -4)]})
            # left hand on the hip: arm out and back, elbow bent hard
            pose.update(arm("L", down=10, out=0, fwd=-25, elbow=95, twist=40))
            hips = (-0.012, 0, hips[2])
        keys.append(dict(f=f, pose=pose, hips=hips))
    return 60, True, keys


def _chop_body(look_down=10, crouch=0.01):
    return {"Spine": [("X", 4)], "Spine1": [("X", 3)], "Head": [("X", look_down)]}


def clip_chop(c):
    tony = c == "tony"
    look = 2 if tony else 10
    left_hold = arm("L", down=28, fwd=40, elbow=70, twist=-20)
    left_slide = arm("L", down=28, fwd=40, out=6, elbow=70, twist=-20)

    def up(left):
        r = arm("R", down=10, fwd=70 + (25 if tony else 0), elbow=125, twist=-15, hand=-25)
        return merge(_chop_body(look), left, r)

    def hit(left):
        r = arm("R", down=30, fwd=30, elbow=40, twist=-15, hand=20)
        return merge(_chop_body(look + 4), left, r, {"RightShoulder": [("to", "DOWN", 6)]})

    def bounce(left):
        r = arm("R", down=28, fwd=36, elbow=52, twist=-15, hand=8)
        return merge(_chop_body(look + 2), left, r)

    head_peek = {"Head": [("Z", 12)]} if tony else {}  # Tony glances at the crowd between chops
    keys = [
        dict(f=0, pose=up(left_hold), hips=(0, 0, -0.008)),
        dict(f=5, pose=hit(left_hold), hips=(0, 0, -0.018)),
        dict(f=7, pose=bounce(left_hold), hips=(0, 0, -0.015)),
        dict(f=15, pose=merge(up(left_slide), head_peek), hips=(0, 0, -0.008)),
        dict(f=20, pose=hit(left_slide), hips=(0, 0, -0.018)),
        dict(f=22, pose=bounce(left_slide), hips=(0, 0, -0.015)),
        dict(f=30, pose=up(left_hold), hips=(0, 0, -0.008)),
    ]
    return 30, True, keys


def clip_busy(c):
    tony = c == "tony"
    turn = 28 if tony else 35
    work = merge({"Spine": [("X", 8)], "Head": [("X", 10)]},
                 arm("L", down=26, fwd=35, elbow=60), arm("R", down=26, fwd=35, elbow=60))

    def turned(sign, extra):
        # sign +1 = character's left. Hips turn a little, spine the rest; legs counter-rotate to keep feet planted.
        hip = 0.4 * turn * sign
        body = {"Hips": [("Z", hip)], "LeftUpLeg": [("Z", -hip)], "RightUpLeg": [("Z", -hip)],
                "Spine": [("X", 8), ("Z", 0.3 * turn * sign)], "Spine1": [("Z", 0.3 * turn * sign)],
                "Spine2": [("Y", 4 * sign)]}
        return merge(body, extra)

    reach_left = merge(arm("R", down=18, fwd=60, out=-25, elbow=25), arm("L", down=28, fwd=30, elbow=70))
    grab_left = merge(arm("R", down=24, fwd=55, out=-25, elbow=45, hand=20), arm("L", down=28, fwd=30, elbow=70))
    pan = lambda push: merge(arm("R", down=24, fwd=35 + push, elbow=80 - push, twist=-10, hand=-10),
                             arm("L", down=26, fwd=30, elbow=75))
    head = lambda yaw: {"Head": [("X", 10), ("Z", yaw)]}

    lean_l = (0.012, 0, -0.012)
    lean_r = (-0.012, 0, -0.012)
    keys = [
        dict(f=0, pose=work, hips=(0, 0, -0.008)),
        dict(f=8, pose=head(turn * 0.5), only=True),
        dict(f=12, pose=merge(turned(1, reach_left), head(turn * 0.5)), hips=lean_l),
        dict(f=18, pose=merge(turned(1, grab_left), head(turn * 0.45)), hips=lean_l),
        dict(f=28, pose=merge(work, head(0)), hips=(0, 0, -0.008)),
        dict(f=32, pose=head(-turn * 0.5), only=True),
        dict(f=36, pose=merge(turned(-1, pan(0)), head(-turn * 0.5)), hips=lean_r),
        dict(f=42, pose=merge(turned(-1, pan(25 if tony else 15)), head(-turn * 0.45)), hips=lean_r),
        dict(f=48, pose=merge(turned(-1, pan(0)), head(-turn * 0.5)), hips=lean_r),
        dict(f=54, pose=merge(turned(-1, pan(25 if tony else 15)), head(-turn * 0.45)), hips=lean_r),
        dict(f=62, pose=merge(work, head(0)), hips=(0, 0, -0.008)),
        dict(f=72, pose=work, hips=(0, 0, -0.008)),
    ]
    if tony:  # one big toss instead of two shakes
        keys[7]["pose"] = merge(turned(-1, pan(45)), head(-turn * 0.4), {"Spine1": [("X", -6)]})
        keys[8]["pose"] = merge(turned(-1, pan(-10)), head(-turn * 0.5))
        keys[9]["pose"] = merge(turned(-1, pan(0)), head(-turn * 0.5))
    return 72, True, keys


def clip_victory(c):
    tony = c == "tony"
    neutral = merge(relaxed_arms(), {})
    antic = merge({"Spine": [("X", 14)], "Head": [("X", 8)]},
                  arm("L", down=40, fwd=-35, elbow=20), arm("R", down=40, fwd=-35, elbow=20))
    jump = merge({"Spine": [("X", -6)], "Spine2": [("X", -6)], "Head": [("X", -18)]},
                 arm("L", down=-100, elbow=10), arm("R", down=-100, elbow=10))
    land = merge({"Spine": [("X", 8)], "Head": [("X", -6)]},
                 arm("L", down=-90, elbow=25), arm("R", down=-90, elbow=25))
    fist_hi = merge({"Spine": [("X", -4)], "Spine2": [("X", -4)], "Head": [("X", -12)]},
                    arm("R", down=-102, fwd=8, elbow=15), arm("L", down=28, fwd=10, elbow=105, twist=30))
    fist_lo = merge({"Spine": [("X", -2)], "Head": [("X", -8)]},
                    arm("R", down=-70, fwd=8, elbow=80), arm("L", down=28, fwd=10, elbow=105, twist=30))
    final = merge({"Spine": [("X", -6)], "Spine2": [("X", -6)], "Head": [("X", -14), ("Y", -4)]},
                  arm("R", down=-105, fwd=8, elbow=12), arm("L", down=28, fwd=10, elbow=105, twist=30))
    jump_h = 0.06 if tony else 0.12
    if tony:
        # smug: no big cheer, lean back, point at the rival, other hand on the hip
        jump = merge({"Spine": [("X", -4)], "Head": [("X", -10)]},
                     arm("R", down=-60, out=10, elbow=15), arm("L", down=10, fwd=-25, elbow=95, twist=40))
        land = merge({"Spine": [("X", -6)], "Head": [("X", -8)]},
                     arm("R", down=-40, elbow=20), arm("L", down=10, fwd=-25, elbow=95, twist=40))
        fist_hi = merge({"Spine": [("X", -8)], "Spine2": [("X", -4)], "Head": [("X", -10), ("Y", -8)]},
                        arm("R", down=5, fwd=45, out=40, elbow=5), arm("L", down=10, fwd=-25, elbow=95, twist=40))
        fist_lo = merge({"Spine": [("X", -6)], "Head": [("X", -6), ("Y", -6)]},
                        arm("R", down=8, fwd=40, out=36, elbow=15), arm("L", down=10, fwd=-25, elbow=95, twist=40))
        final = merge({"Spine": [("X", -8)], "Spine2": [("X", -4)], "Head": [("X", -10), ("Y", -10)]},
                      arm("R", down=5, fwd=45, out=42, elbow=0), arm("L", down=10, fwd=-25, elbow=95, twist=40))
    keys = [
        dict(f=0, pose=neutral, hips=(0, 0, 0)),
        dict(f=8, pose=antic, crouch=0.06),
        dict(f=16, pose=jump, hips=(0, 0, jump_h)),
        dict(f=24, pose=land, crouch=0.03),
        dict(f=32, pose=fist_hi, hips=(0, 0, 0)),
        dict(f=38, pose=fist_lo, crouch=0.01),
        dict(f=44, pose=fist_hi, hips=(0, 0, 0)),
        dict(f=50, pose=fist_lo, crouch=0.01),
        dict(f=60, pose=final, hips=(0, 0, 0.005)),
    ]
    return 60, False, keys


def clip_lose(c):
    tony = c == "tony"
    neutral = relaxed_arms()
    shock = merge({"Spine": [("X", -10)], "Spine2": [("X", -4)], "Head": [("X", -8)],
                   "LeftShoulder": [("to", "UP", 10)], "RightShoulder": [("to", "UP", 10)]},
                  arm("L", down=0, fwd=35, elbow=60), arm("R", down=0, fwd=35, elbow=60))
    slump = merge({"Spine": [("X", 6)], "Spine1": [("X", 4)], "Spine2": [("X", 3)], "Head": [("X", 14)],
                   "LeftShoulder": [("to", "DOWN", 8)], "RightShoulder": [("to", "DOWN", 8)]},
                  relaxed_arms(extra_down=18))
    down = merge({"Spine": [("X", 8)], "Spine1": [("X", 5)], "Spine2": [("X", 4)], "Head": [("X", 20)],
                  "LeftShoulder": [("to", "DOWN", 10)], "RightShoulder": [("to", "DOWN", 10)]},
                 arm("L", down=50, fwd=10, elbow=5), arm("R", down=50, fwd=10, elbow=5))
    sway = merge(down, {"Head": [("Y", 4)], "Spine2": [("Y", 3)]})
    keys = [
        dict(f=0, pose=neutral, hips=(0, 0, 0)),
        dict(f=6, pose=shock, hips=(0, 0.01, 0.01)),
        dict(f=14, pose=shock, hips=(0, 0.01, 0.008)),
        dict(f=36, pose=slump, crouch=0.02),
        dict(f=52, pose=down, crouch=0.08),
        dict(f=62, pose=sway, crouch=0.075),
        dict(f=72, pose=down, crouch=0.08),
    ]
    if tony:
        # dramatic: grabs his head, then drops to his knees
        grab = merge({"Spine": [("X", -6)], "Head": [("X", 10)]},
                     arm("L", down=-60, fwd=40, elbow=130), arm("R", down=-60, fwd=40, elbow=130))
        kneel = merge({"Spine": [("X", 10)], "Spine1": [("X", 6)], "Spine2": [("X", 4)], "Head": [("X", 18)]},
                      arm("L", down=50, fwd=15, elbow=10), arm("R", down=50, fwd=15, elbow=10))
        keys[3] = dict(f=36, pose=grab, crouch=0.02)
        keys[4] = dict(f=52, pose=kneel, kneel=True)
        keys[5] = dict(f=62, pose=merge(kneel, {"Head": [("Y", 5)]}), kneel=True)
        keys[6] = dict(f=72, pose=kneel, kneel=True)
    return 72, False, keys


CLIPS = [("idle", clip_idle), ("chop", clip_chop), ("busy", clip_busy), ("victory", clip_victory), ("lose", clip_lose)]


# ---------------------------------------------------------------------------------------------
# Rig math
# ---------------------------------------------------------------------------------------------

class Rig:
    def __init__(self, arm_obj):
        self.obj = arm_obj
        W = arm_obj.matrix_world.to_3x3()
        self.R = {}      # bone rest orientation in world (quaternion)
        self.dir = {}    # bone rest direction in world (unit)
        for b in arm_obj.data.bones:
            m = W @ b.matrix_local.to_3x3()
            self.R[b.name] = m.to_quaternion()
            self.dir[b.name] = (W @ (b.tail_local - b.head_local)).normalized()
        self.hips_h = (arm_obj.matrix_world @ arm_obj.data.bones[B + "Hips"].head_local).z
        self.k = self.hips_h / 0.248   # Apis hip height is the authoring reference
        # leg geometry for the crouch solver (left leg; rig is near-symmetric)
        bones = arm_obj.data.bones
        hip = W @ bones[B + "LeftUpLeg"].head_local
        knee = W @ bones[B + "LeftLeg"].head_local
        ankle = W @ bones[B + "LeftFoot"].head_local
        self.L1 = (knee - hip).length
        self.L2 = (ankle - knee).length
        self.h0 = hip.z - ankle.z

    def side_dir(self, bone, name):
        if name in DIRS:
            return DIRS[name]
        left = "Left" in bone
        out = Vector((1, 0, 0)) if left else Vector((-1, 0, 0))
        return out if name == "OUT" else -out

    def world_delta(self, bone, ops):
        """Compose ops into one world-frame rotation applied at rest."""
        q = Quaternion()
        d0 = self.dir[bone]
        for op in ops:
            d = q @ d0
            if op[0] in ("X", "Y", "Z"):
                axis = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}[op[0]]
                step = Quaternion(axis, math.radians(op[1]))
            elif op[0] == "to":
                target = self.side_dir(bone, op[1])
                axis = d.cross(target)
                if axis.length < 1e-6:
                    continue
                step = Quaternion(axis.normalized(), math.radians(op[2]))
            elif op[0] == "flex":
                # hinge fixed in the parent's frame: bends the rest direction toward the front
                axis = d0.cross(DIRS["FWD"])
                if axis.length < 1e-6:
                    axis = Vector((1, 0, 0))
                step = Quaternion(axis.normalized(), math.radians(op[1]))
            elif op[0] == "twist":
                step = Quaternion(d, math.radians(op[1]))
            else:
                raise ValueError(op)
            q = step @ q
        return q

    def local(self, bone, world_q):
        R = self.R[bone]
        return R.inverted() @ world_q @ R

    def local_loc(self, bone, v):
        return self.R[bone].inverted() @ Vector(v)

    def crouch_ops(self, drop):
        """Planar two-bone IK: lower the hips by `drop` m with feet planted and flat."""
        def angles(h):
            h = max(min(h, self.L1 + self.L2 - 1e-5), abs(self.L1 - self.L2) + 1e-4)
            a = math.acos((self.L1 ** 2 + h ** 2 - self.L2 ** 2) / (2 * self.L1 * h))
            b = math.acos((self.L2 ** 2 + h ** 2 - self.L1 ** 2) / (2 * self.L2 * h))
            return a, b
        a0, b0 = angles(self.h0)
        a1, b1 = angles(self.h0 - drop)
        da, db = math.degrees(a1 - a0), math.degrees(b1 - b0)
        ops = {}
        for s in ("Left", "Right"):
            ops[s + "UpLeg"] = [("X", -da)]          # thigh forward
            ops[s + "Leg"] = [("X", da + db)]        # knee back
            ops[s + "Foot"] = [("X", -db)]           # keep the sole flat
        return ops

    def kneel_ops(self):
        ops = {}
        for s in ("Left", "Right"):
            ops[s + "UpLeg"] = [("X", -8)]
            ops[s + "Leg"] = [("X", 100)]
            ops[s + "Foot"] = [("X", 30)]
        return ops, self.L2 * 0.95


# ---------------------------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------------------------

def scale_ops(ops, amp):
    out = []
    for op in ops:
        if op[0] == "to":
            out.append((op[0], op[1], op[2] * amp))
        else:
            out.append((op[0], op[1] * amp))
    return out


def build_clip(rig, char, name, fn):
    style = STYLES[char]
    frames, loop, keys = fn(char)
    tempo = style["tempo"][name]
    amp = style["amp"]
    arm_obj = rig.obj
    ad = arm_obj.animation_data or arm_obj.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad.action = act

    # every bone touched anywhere in the clip (plus base posture) is keyed on every full key
    touched = set(style["base"].keys()) | {"Hips"}
    for k in keys:
        touched |= set(k["pose"].keys())
        if k.get("crouch") or k.get("kneel"):
            touched |= {s + p for s in ("Left", "Right") for p in ("UpLeg", "Leg", "Foot")}
    touched = sorted(touched)

    prev = {}
    for k in keys:
        f = round(k["f"] * tempo) + 1
        pose = {b: scale_ops(o, amp) for b, o in k["pose"].items()}
        hips = Vector(k.get("hips", (0, 0, 0))) * amp * rig.k
        if k.get("crouch"):
            pose = merge(pose, rig.crouch_ops(k["crouch"] * amp * rig.k))
            hips = hips + Vector((0, 0, -k["crouch"] * amp * rig.k))
        if k.get("kneel"):
            kops, drop = rig.kneel_ops()
            pose = merge(pose, kops)
            hips = hips + Vector((0, 0, -drop))
        bones = sorted(pose.keys()) if k.get("only") else touched
        for short in bones:
            name_b = B + short
            pb = arm_obj.pose.bones[name_b]
            ops = style["base"].get(short, []) + pose.get(short, [])
            ql = rig.local(name_b, rig.world_delta(name_b, ops))
            if name_b in prev and prev[name_b].dot(ql) < 0:
                ql.negate()
            prev[name_b] = ql
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = ql
            pb.keyframe_insert("rotation_quaternion", frame=f, group=name_b)
            if short == "Hips" and not k.get("only"):
                pb.location = rig.local_loc(name_b, hips)
                pb.keyframe_insert("location", frame=f, group=name_b)

    end = round(frames * tempo) + 1
    act.frame_range = (1, end)
    act.use_frame_range = True
    act.use_cyclic = loop

    # stash in the NLA so the exporter (Actions mode) sees every clip
    track = ad.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, act)
    track.mute = True
    ad.action = None
    return act, end, loop


def reset_pose(arm_obj):
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()


# ---------------------------------------------------------------------------------------------
# Contact sheet
# ---------------------------------------------------------------------------------------------

def render_sheet(arm_obj, clips, path, cols=8, size=200):
    import numpy as np
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    world = bpy.data.worlds.new("w") if not scene.world else scene.world
    scene.world = world
    world.color = (0.18, 0.19, 0.22)
    cam_data = bpy.data.cameras.new("sheet_cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 1.25
    cam = bpy.data.objects.new("sheet_cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (1.1, -2.6, 0.75)
    look = Vector((0, 0, 0.48)) - cam.location
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    ad = arm_obj.animation_data
    tmp = os.path.join(os.path.dirname(path), "_frame.png")
    rows = []
    for name, act, end, _loop in clips:
        ad.action = act
        row = []
        for i in range(cols):
            f = 1 + round(i * (end - 1) / (cols - 1))
            scene.frame_set(f)
            scene.render.filepath = tmp
            bpy.ops.render.render(write_still=True)
            img = bpy.data.images.load(tmp, check_existing=False)
            px = np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4)
            bpy.data.images.remove(img)
            row.append(px)
        rows.append(np.concatenate(row, axis=1))
        ad.action = None
    sheet = np.concatenate(rows[::-1], axis=0)  # pixels are bottom-up: first clip ends on top
    h, w = sheet.shape[:2]
    out = bpy.data.images.new("sheet", w, h)
    out.pixels = sheet.ravel()
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    os.remove(tmp)
    bpy.data.objects.remove(cam)


# ---------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    char = argv[0] if argv else "apis"
    sheet = argv[argv.index("--sheet") + 1] if "--sheet" in argv else None
    do_export = "--no-export" not in argv

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "art", "blender", "src", f"{char}_src.glb"))
    scene = bpy.context.scene
    scene.render.fps = FPS
    arm_obj = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    mesh_obj = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm_obj)
    arm_obj.name = "Armature"
    mesh_obj.name = f"{char}_body"
    rig = Rig(arm_obj)

    clips = []
    for name, fn in CLIPS:
        reset_pose(arm_obj)
        act, end, loop = build_clip(rig, char, name, fn)
        clips.append((name, act, end, loop))
        print(f"CLIP {name}: frames 1-{end} ({(end - 1) / FPS:.2f}s) loop={loop}")
    reset_pose(arm_obj)
    scene.frame_start, scene.frame_end = 1, max(c[2] for c in clips)

    if sheet:
        render_sheet(arm_obj, clips, sheet)
        print("SHEET", sheet)

    if do_export:
        blend = os.path.join(ROOT, "art", "blender", f"{char}_anim.blend")
        bpy.ops.wm.save_as_mainfile(filepath=blend)
        bpy.ops.object.select_all(action="DESELECT")
        arm_obj.select_set(True)
        mesh_obj.select_set(True)
        bpy.context.view_layer.objects.active = arm_obj
        out = os.path.join(ROOT, "godot", "assets", "characters", f"{char}.glb")
        bpy.ops.export_scene.gltf(
            filepath=out,
            export_format="GLB",
            use_selection=True,
            export_yup=True,
            export_animations=True,
            export_animation_mode="ACTIONS",
            export_force_sampling=True,
            export_frame_range=False,
            export_anim_single_armature=True,
            export_reset_pose_bones=True,
            export_cameras=False,
            export_lights=False,
        )
        print("EXPORT", out, "BLEND", blend)


main()
