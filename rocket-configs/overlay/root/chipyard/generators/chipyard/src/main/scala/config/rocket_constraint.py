from __future__ import annotations

from typing import Any, Dict, List, Optional

DEFAULT_TL_BEAT_BYTES = 8


def _is_pow2(n: int) -> bool:
    return n > 0 and (n & (n - 1)) == 0


def _log2_ceil(n: int) -> int:
    if n <= 1:
        return 0
    return (n - 1).bit_length()


def validate_params(params: Dict[str, Any]) -> List[str]:
    errors: List[str] = []

    def _get_int(key: str) -> Optional[int]:
        if key not in params:
            return None
        return int(params.get(key))

    def _get_bool(key: str) -> Optional[bool]:
        if key not in params:
            return None
        v = params.get(key)
        if isinstance(v, bool):
            return v
        if isinstance(v, str):
            return v.lower() == "true"
        return bool(v)

    def _has(*keys: str) -> bool:
        return all(k in params for k in keys)

    # Basic sanity
    if _has("numCores") and _get_int("numCores") <= 0:
        errors.append("numCores must be > 0")
    if _has("l1ICacheSets", "l1ICacheWays"):
        if _get_int("l1ICacheSets") <= 0 or _get_int("l1ICacheWays") <= 0:
            errors.append("l1 I$ sets/ways must be > 0")
    if _has("l1DCacheSets", "l1DCacheWays"):
        if _get_int("l1DCacheSets") <= 0 or _get_int("l1DCacheWays") <= 0:
            errors.append("l1 D$ sets/ways must be > 0")

    # Tiny core constraints (Tiny core uses scratchpad D$)
    if _has("useTinyCore", "l1DCacheMSHRs"):
        if _get_bool("useTinyCore") and _get_int("l1DCacheMSHRs") != 0:
            errors.append("useTinyCore requires l1DCacheMSHRs=0")
    if _has("useTinyCore", "enableMemPort"):
        if _get_bool("useTinyCore") and _get_bool("enableMemPort"):
            errors.append("useTinyCore requires enableMemPort=false (overlaps TCM @ 0x8000_0000)")

    # Incoherent topology has no MBUS or coherence manager
    if _has("useIncoherentBus", "useTinyCore"):
        if _get_bool("useIncoherentBus") and not _get_bool("useTinyCore"):
            errors.append("useIncoherentBus requires useTinyCore=true (no coherent managers)")
    if _has("useIncoherentBus", "enableMemPort"):
        if _get_bool("useIncoherentBus") and _get_bool("enableMemPort"):
            errors.append("useIncoherentBus requires enableMemPort=false (no MBUS)")
    if _has("useIncoherentBus", "enableL2"):
        if _get_bool("useIncoherentBus") and _get_bool("enableL2"):
            errors.append("useIncoherentBus requires enableL2=false (no coherent L2)")
    if _has("useIncoherentBus", "disableScratchpads"):
        if _get_bool("useIncoherentBus") and not _get_bool("disableScratchpads"):
            errors.append("useIncoherentBus requires disableScratchpads=true (no MBUS)")

    # Coherent topology but no memory managers attached
    if _has("useIncoherentBus", "enableMemPort", "disableScratchpads"):
        if (not _get_bool("useIncoherentBus")
                and not _get_bool("enableMemPort")
                and _get_bool("disableScratchpads")):
            errors.append("coherent bus requires enableMemPort or scratchpads")

    # Coherent topology needs an L2 in this setup (no MBUS without it)
    if _has("useIncoherentBus", "enableL2"):
        if (not _get_bool("useIncoherentBus")) and (not _get_bool("enableL2")):
            errors.append("coherent bus requires enableL2=true (MBUS absent without L2)")

    # When L2 is disabled, MBUS is not present in this setup; scratchpads must be off
    if _has("enableL2", "disableScratchpads"):
        if (not _get_bool("enableL2")) and not _get_bool("disableScratchpads"):
            errors.append("enableL2=false requires disableScratchpads=true (MBUS absent)")

    # Non-blocking D$ constraint: untagBits must fit within pgIdxBits (4KiB pages => 12 bits)
    if _has("l1DCacheMSHRs", "cacheBlockBytes", "l1DCacheSets"):
        if _get_int("l1DCacheMSHRs") > 0:
            block_bytes = _get_int("cacheBlockBytes")
            l1d_sets = _get_int("l1DCacheSets")
            if _log2_ceil(block_bytes) + _log2_ceil(l1d_sets) > 12:
                errors.append("nonblocking L1D requires log2(blockBytes)+log2(nSets) <= 12")

    # L2 (inclusive cache) constraints from InclusiveCacheParameters
    if _has(
        "enableL2",
        "l2Ways",
        "l2Banks",
        "l2CapacityKB",
        "cacheBlockBytes",
        "l2WriteBytes",
        "l2SubBankingFactor",
        "l2OuterLatencyCycles",
        "l2BankedControl",
    ):
        if _get_bool("enableL2"):
            l2_ways = _get_int("l2Ways")
            l2_banks = _get_int("l2Banks")
            l2_cap_kb = _get_int("l2CapacityKB")
            block_bytes = _get_int("cacheBlockBytes")
            write_bytes = _get_int("l2WriteBytes")
            port_factor = _get_int("l2SubBankingFactor")
            mem_cycles = _get_int("l2OuterLatencyCycles")

            if l2_ways <= 1:
                errors.append("l2Ways must be > 1")
            if l2_banks < 1:
                errors.append("l2Banks must be >= 1 when enableL2")
            if l2_cap_kb <= 0:
                errors.append("l2CapacityKB must be > 0")
            if block_bytes <= 0:
                errors.append("cacheBlockBytes must be > 0")
            if not _is_pow2(block_bytes):
                errors.append("cacheBlockBytes must be power of two")
            if write_bytes <= 0 or not _is_pow2(write_bytes):
                errors.append("l2WriteBytes must be power of two > 0")
            if write_bytes > DEFAULT_TL_BEAT_BYTES:
                errors.append("l2WriteBytes must be <= TL beatBytes (8)")
            if block_bytes % write_bytes != 0:
                errors.append("cacheBlockBytes must be a multiple of l2WriteBytes")
            if port_factor < 2:
                errors.append("l2SubBankingFactor must be >= 2")
            if mem_cycles <= 0:
                errors.append("l2OuterLatencyCycles must be > 0")
            if l2_banks > 1 and port_factor < 4:
                errors.append("l2Banks>1 requires l2SubBankingFactor >= 4")

            if _get_bool("l2BankedControl"):
                beats_per_block = block_bytes // write_bytes if write_bytes else 0
                if beats_per_block <= 0:
                    errors.append("invalid cacheBlockBytes/l2WriteBytes ratio")
                elif port_factor < beats_per_block:
                    errors.append("l2BankedControl requires l2SubBankingFactor >= cacheBlockBytes/l2WriteBytes")

            denom = block_bytes * l2_ways * l2_banks
            total_bytes = l2_cap_kb * 1024
            if denom <= 0:
                errors.append("invalid L2 denominator for sets")
            elif total_bytes % denom != 0:
                errors.append("l2CapacityKB not divisible by blockBytes*ways*banks")
            else:
                l2_sets = total_bytes // denom
                if l2_sets <= 1 or not _is_pow2(l2_sets):
                    errors.append("l2 sets must be > 1 and power of two")

    return errors
