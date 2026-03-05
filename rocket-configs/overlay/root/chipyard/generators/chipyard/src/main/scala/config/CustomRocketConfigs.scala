package chipyard

import org.chipsalliance.cde.config.{Config, Parameters}

// Edit these to customize Rocket cache geometry, line size, and core composition.
object CustomRocketParams {
  // Core composition
  val useTinyCore: Boolean = false
  val numCores: Int = 1               // used when useTinyCore = false
  val useRV32: Boolean = false

  // Cache line size (bytes)
  val cacheBlockBytes: Int = 32

  // L1 cache geometry
  val l1ICacheSets: Int = 64
  val l1ICacheWays: Int = 2
  val l1DCacheSets: Int = 64
  val l1DCacheWays: Int = 2

  // L1 D$ nonblocking (set to 0 to disable). Tiny cores use a scratchpad-style cache,
  // so keep this disabled unless useTinyCore = false.
  val l1DCacheMSHRs: Int = 0

  // Core micro-architecture knobs
  val l2TLBEntries: Int = 0
  val nPerfCounters: Int = 0
  val nPMPs: Int = 0
  val enableTilePrefetchers: Boolean = false

  // L2 configuration
  val enableL2: Boolean = true
  // L2 cache tuning (inclusive LLC)
  val l2CapacityKB: Int = 512
  val l2Ways: Int = 4
  val l2OuterLatencyCycles: Int = 40
  val l2SubBankingFactor: Int = 2
  val l2HintsSkipProbe: Boolean = false
  val l2BankedControl: Boolean = false
  val l2CtrlAddr: Option[Int] = None
  val l2WriteBytes: Int = 8
  val l2Banks: Int = 2

  // System topology
  val useIncoherentBus: Boolean = false
  val enableMemPort: Boolean = true
  val disableScratchpads: Boolean = false
}

private object CustomRocketConfigFragments {
  def build: Parameters = {
    // Derived knobs to keep the config internally consistent.
    val useTinyCore = CustomRocketParams.useTinyCore
    val effectiveL1DCacheMSHRs =
      if (useTinyCore) 0 else CustomRocketParams.l1DCacheMSHRs
    val useIncoherentBus = CustomRocketParams.useIncoherentBus
    val enableL2 =
      if (useIncoherentBus) false else CustomRocketParams.enableL2
    val enableMemPort =
      if (useIncoherentBus) false else CustomRocketParams.enableMemPort
    val effectiveL2Banks =
      if (enableL2) math.max(1, CustomRocketParams.l2Banks) else 0

    val baseConfs: Seq[Config] = Seq(
      new chipyard.config.WithCacheBlockBytes(CustomRocketParams.cacheBlockBytes),
      new chipyard.config.WithRocketL1ICacheSets(CustomRocketParams.l1ICacheSets),
      new chipyard.config.WithRocketL1ICacheWays(CustomRocketParams.l1ICacheWays)
    ) ++ (if (CustomRocketParams.useTinyCore) Seq.empty else Seq(
      new chipyard.config.WithRocketL1DCacheSets(CustomRocketParams.l1DCacheSets),
      new chipyard.config.WithRocketL1DCacheWays(CustomRocketParams.l1DCacheWays)
    ))

    val l1dNonblocking: Seq[Config] =
      if (effectiveL1DCacheMSHRs > 0)
        Seq(new freechips.rocketchip.rocket.WithL1DCacheNonblocking(effectiveL1DCacheMSHRs))
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
      if (enableL2) Seq(
        new freechips.rocketchip.subsystem.WithInclusiveCache(
          nWays = CustomRocketParams.l2Ways,
          capacityKB = CustomRocketParams.l2CapacityKB,
          outerLatencyCycles = CustomRocketParams.l2OuterLatencyCycles,
          subBankingFactor = CustomRocketParams.l2SubBankingFactor,
          hintsSkipProbe = CustomRocketParams.l2HintsSkipProbe,
          bankedControl = CustomRocketParams.l2BankedControl,
          ctrlAddr = CustomRocketParams.l2CtrlAddr,
          writeBytes = CustomRocketParams.l2WriteBytes
        ),
        new freechips.rocketchip.subsystem.WithNBanks(effectiveL2Banks)
      )
      else Seq(new freechips.rocketchip.subsystem.WithNBanks(0))

    val memPort: Seq[Config] =
      if (enableMemPort) Seq.empty
      else Seq(new freechips.rocketchip.subsystem.WithNoMemPort)

    val bus: Seq[Config] =
      if (useIncoherentBus) Seq(new freechips.rocketchip.subsystem.WithIncoherentBusTopology)
      else Seq.empty

    val scratchpads: Seq[Config] =
      if (CustomRocketParams.disableScratchpads) Seq(new testchipip.soc.WithNoScratchpads)
      else Seq.empty

    val core: Seq[Config] =
      if (useTinyCore)
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
