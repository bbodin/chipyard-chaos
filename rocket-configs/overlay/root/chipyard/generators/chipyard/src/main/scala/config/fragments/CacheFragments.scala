package chipyard.config

import org.chipsalliance.cde.config.Config
import freechips.rocketchip.subsystem.{CacheBlockBytes, InSubsystem, RocketTileAttachParams, TilesLocated}

class WithCacheBlockBytes(bytes: Int) extends Config((site, here, up) => {
  case CacheBlockBytes => bytes
})

class WithRocketL1ICacheSets(nSets: Int) extends Config((site, here, up) => {
  case TilesLocated(InSubsystem) => up(TilesLocated(InSubsystem), site) map {
    case tp: RocketTileAttachParams => tp.copy(tileParams = tp.tileParams.copy(
      icache = tp.tileParams.icache.map(_.copy(nSets = nSets))))
    case other => other
  }
})

class WithRocketL1ICacheWays(nWays: Int) extends Config((site, here, up) => {
  case TilesLocated(InSubsystem) => up(TilesLocated(InSubsystem), site) map {
    case tp: RocketTileAttachParams => tp.copy(tileParams = tp.tileParams.copy(
      icache = tp.tileParams.icache.map(_.copy(nWays = nWays))))
    case other => other
  }
})

class WithRocketL1DCacheSets(nSets: Int) extends Config((site, here, up) => {
  case TilesLocated(InSubsystem) => up(TilesLocated(InSubsystem), site) map {
    case tp: RocketTileAttachParams => tp.copy(tileParams = tp.tileParams.copy(
      dcache = tp.tileParams.dcache.map(_.copy(nSets = nSets))))
    case other => other
  }
})

class WithRocketL1DCacheWays(nWays: Int) extends Config((site, here, up) => {
  case TilesLocated(InSubsystem) => up(TilesLocated(InSubsystem), site) map {
    case tp: RocketTileAttachParams => tp.copy(tileParams = tp.tileParams.copy(
      dcache = tp.tileParams.dcache.map(_.copy(nWays = nWays))))
    case other => other
  }
})

class WithRocketL1DCacheMSHRs(nMSHRs: Int) extends Config((site, here, up) => {
  case TilesLocated(InSubsystem) => up(TilesLocated(InSubsystem), site) map {
    case tp: RocketTileAttachParams => tp.copy(tileParams = tp.tileParams.copy(
      dcache = tp.tileParams.dcache.map(_.copy(nMSHRs = nMSHRs))))
    case other => other
  }
})
