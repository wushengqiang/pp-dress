# Epic: 服装数据库

> **Layer**: Foundation
> **GDD**: design/gdd/wardrobe-database.md
> **Architecture Module**: WardrobeDatabase
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories wardrobe-database`

## Overview

实现静态服装数据的唯一权威来源，负责加载、校验、索引和只读查询服装条目。它为衣橱 UI、精灵分层渲染、资源加载、进度计算和服装解锁提供一致的数据契约，保证所有消费方看到同一份结构化服装定义。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0010: Wardrobe Database Schema and Read-Only Query Contract | 单 JSON 数据源、同步 Autoload 加载、只读查询、防御性拷贝、确定性排序与 z-index 解析 | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-wardrobe-database-001 | Static wardrobe JSON schema, read-only query API, z-index resolution, unlock-day metadata, deterministic ordering, and schema validation. | ADR-0010 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/wardrobe-database.md` are verified
- All logic and integration stories have passing tests in `tests/`
- All schema and query behavior matches the approved ADR contract

## Next Step

Run `/create-stories wardrobe-database` to break this epic into implementable stories.
