class_name CrowdClock
extends RefCounted
## The clock crowd animations play against. It wraps, because per-instance
## data is only 16-bit on the Compatibility renderer: start times stay small
## and precise, and the shader measures elapsed time modulo WRAP.
## No clip may be longer than WRAP seconds.

const WRAP := 64.0
