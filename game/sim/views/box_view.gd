class_name BoxView
extends RefCounted

## Read-only view of one resolved box in world space (inspection-surface.md →
## BoxView).
##
## The geometry the sim actually tests for overlap this tick (derived, not stored —
## AD-001), projected as plain data. `rect` is a world-space AABB in FIXED-POINT
## (sim truth; snapshot-able, no floats — AD-019). The UI converts to px for
## drawing via the InspectionView render projection; px is never a field here.

## HURT | HIT | THROW | PUSH.
var kind: int = KIND_HURT

## World-space AABB, fixed-point: { x, y, w, h }.
var rect: Dictionary = {"x": 0, "y": 0, "w": 0, "h": 0}

## For HIT / THROW: hit data. Empty for HURT / PUSH.
## { damage, hitstun, blockstun, hitstop, id_group, rehit_interval }.
var hit: Dictionary = {}

const KIND_HURT: int = 0
const KIND_HIT: int = 1
const KIND_THROW: int = 2
const KIND_PUSH: int = 3


## Build from a ResolvedBox (the sim's box-resolution output — MoveData.resolve_boxes).
## Single source of truth: the view shows exactly the box the sim tests.
static func from_resolved(rb: ResolvedBox) -> BoxView:
	var v := BoxView.new()
	v.kind = rb.kind
	v.rect = {"x": rb.x, "y": rb.y, "w": rb.w, "h": rb.h}
	if rb.hit != null:
		v.hit = {
			"damage": rb.hit.damage,
			"hitstun": rb.hit.hitstun,
			"blockstun": rb.hit.blockstun,
			"hitstop": rb.hit.hitstop,
			"id_group": rb.hit.id_group,
			"rehit_interval": rb.hit.rehit_interval,
		}
	return v
