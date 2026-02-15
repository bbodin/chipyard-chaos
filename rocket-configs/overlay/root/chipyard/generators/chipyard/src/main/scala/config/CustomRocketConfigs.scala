package chipyard

import org.chipsalliance.cde.config.{Config, Parameters}

// Edit these to customize Rocket cache geometry, line size, and core composition.
object CustomRocketParams {
  // Core composition
  val useTinyCore: Boolean = true
  val numCores: Int = 1               // used when useTinyCore = false
  val useRV32: Boolean = true

  // Cache line size (bytes)
  val cacheBlockBytes: Int = 64

  // L1 cache geometry
  val l1ICacheSets: Int = 32
  val l1ICacheWays: Int = 1
  val l1DCacheSets: Int = 64
  val l1DCacheWays: Int = 4

  // L1 D$ nonblocking (set to 0 to disable). Tiny cores use a scratchpad-style cache,
  // so keep this disabled unless useTinyCore = false.
  val l1DCacheMSHRs: Int = 0

  // Core micro-architecture knobs
  val l2TLBEntries: Int = 0
  val nPerfCounters: Int = 0
  val nPMPs: Int = 0
  val enableTilePrefetchers: Boolean = false

  // L2 configuration
  val enableL2: Boolean = false

  // System topology
  val useIncoherentBus: Boolean = true
  val enableMemPort: Boolean = false
  val disableScratchpads: Boolean = true
}

private object CustomRocketConfigFragments {
  def build: Parameters = {
    val baseConfs: Seq[Config] = Seq(
      new chipyard.config.WithCacheBlockBytes(CustomRocketParams.cacheBlockBytes),
      new chipyard.config.WithRocketL1ICacheSets(CustomRocketParams.l1ICacheSets),
      new chipyard.config.WithRocketL1ICacheWays(CustomRocketParams.l1ICacheWays)
    ) ++ (if (CustomRocketParams.useTinyCore) Seq.empty else Seq(
      new chipyard.config.WithRocketL1DCacheSets(CustomRocketParams.l1DCacheSets),
      new chipyard.config.WithRocketL1DCacheWays(CustomRocketParams.l1DCacheWays)
    ))

    val l1dNonblocking: Seq[Config] =
      if (CustomRocketParams.l1DCacheMSHRs > 0 && !CustomRocketParams.useTinyCore)
        Seq(new freechips.rocketchip.rocket.WithL1DCacheNonblocking(CustomRocketParams.l1DCacheMSHRs))
      else
        Seq.empty

    val coreKnobs: Seq[Config] = Seq(
      new chipyard.config.WithL2TLBs(CustomRocketParams.l2TLBEntries),
      new chipyard.config.WithNPerfCounters(CustomRocketParams.nPerfCounters),
      new chipyard.config.WithNPMPs(CustomRocketParams.nPMPs)
    )

    val prefetchers: Seq[Config] =
      if (CustomRocketParams.enableTilePrefetchers) Seq(new chipyard.config.WithTilePrefetchers) else Seq.empty

    val l2: Seq[Config] =
      if (CustomRocketParams.enableL2) Seq.empty
      else Seq(new freechips.rocketchip.subsystem.WithNBanks(0))

    val memPort: Seq[Config] =
      if (CustomRocketParams.enableMemPort) Seq.empty
      else Seq(new freechips.rocketchip.subsystem.WithNoMemPort)

    val bus: Seq[Config] =
      if (CustomRocketParams.useIncoherentBus) Seq(new freechips.rocketchip.subsystem.WithIncoherentBusTopology)
      else Seq.empty

    val scratchpads: Seq[Config] =
      if (CustomRocketParams.disableScratchpads) Seq(new testchipip.soc.WithNoScratchpads)
      else Seq.empty

    val core: Seq[Config] =
      if (CustomRocketParams.useTinyCore)
        Seq(new freechips.rocketchip.rocket.With1TinyCore)
      else
        Seq(new freechips.rocketchip.rocket.WithNHugeCores(CustomRocketParams.numCores))

    val rv32: Seq[Config] =
      if (CustomRocketParams.useRV32) Seq(new freechips.rocketchip.rocket.WithRV32) else Seq.empty

    val all = baseConfs ++ l1dNonblocking ++ coreKnobs ++ prefetchers ++ l2 ++ memPort ++ bus ++ scratchpads ++ core ++ rv32

    val baseParams: Parameters = new chipyard.config.AbstractConfig
    all.foldRight(baseParams) { (c, acc) => c ++ acc }
  }
}

class CustomRocketConfig extends Config(
  CustomRocketConfigFragments.build)
