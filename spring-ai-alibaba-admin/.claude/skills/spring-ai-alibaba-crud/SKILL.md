---
name: spring-ai-alibaba-crud
description: CRUD code generation patterns for Spring AI Alibaba Admin. Covers Entity, DTO, Mapper, Service, Controller layer scaffolding following project conventions. Use when adding new CRUD endpoints or entities.
origin: project
---

# Spring AI Alibaba Admin CRUD Patterns

Project-specific scaffolding patterns for adding new CRUD resources to the admin platform.

## When to Activate

- Adding a new entity with full CRUD API
- Creating a new Controller with standard endpoints
- Generating Mapper XML for MyBatis Plus
- Writing Service layer with transaction management
- Building DTO converters from Entity classes

## Layer Structure

```
Controller (thin) → Service (business logic) → Mapper (data access) → MySQL
     ↓                    ↓
  Request DTO         Entity (DO)
     ↓                    ↓
  Response DTO        Result<T> wrapper
```

## 1. Entity (DO)

Location: `spring-ai-alibaba-admin-server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/entity/`

```java
package com.alibaba.cloud.ai.studio.admin.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "your_table_name")
public class YourEntityDO {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    private String description;

    @Column(columnDefinition = "LONGTEXT")
    private String content;

    private LocalDateTime createTime;

    private LocalDateTime updateTime;

    private Integer deleted;  // 0=normal, 1=deleted (if soft-delete needed)
}
```

**Conventions:**
- Class suffix: `DO` (Data Object)
- `@Data @Builder @NoArgsConstructor @AllArgsConstructor` on every entity
- `@Id @GeneratedValue(strategy = GenerationType.IDENTITY)` for primary key
- `LocalDateTime` for timestamps
- `Integer deleted` for soft-delete (0/1)
- JSON fields use `@Column(columnDefinition = "LONGTEXT")`

## 2. DTO

Location: `spring-ai-alibaba-admin-server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/dto/`

```java
package com.alibaba.cloud.ai.studio.admin.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class YourEntity {

    private Long id;
    private String name;
    private String description;
    private String content;
    private LocalDateTime createTime;
    private LocalDateTime updateTime;

    /**
     * Convert from DO to DTO.
     */
    public static YourEntity fromDO(YourEntityDO DO) {
        if (DO == null) {
            return null;
        }
        return YourEntity.builder()
                .id(DO.getId())
                .name(DO.getName())
                .description(DO.getDescription())
                .content(DO.getContent())
                .createTime(DO.getCreateTime())
                .updateTime(DO.getUpdateTime())
                .build();
    }
}
```

**Conventions:**
- No `DO` suffix in DTO name
- `static fromDO(EntityDO)` converter method
- Use `@Builder` pattern
- Timestamps as `LocalDateTime` in DTO (convert to epoch millis only at API boundary if needed)

## 3. Request DTOs

Location: same as DTO, under `dto/request/`

```java
package com.alibaba.cloud.ai.studio.admin.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class YourEntityCreateRequest {

    @NotBlank(message = "Name is required")
    private String name;

    private String description;

    private String content;
}

@Data
public class YourEntityUpdateRequest {

    @NotBlank(message = "ID is required")
    private Long id;

    private String name;

    private String description;

    private String content;
}

@Data
public class YourEntityListRequest {

    private String search;  // "accurate" or "blur"
    private String keyword;
    private Integer pageNo = 1;
    private Integer pageSize = 20;
}
```

**Conventions:**
- `@NotBlank` for required fields
- List requests include `pageNo`, `pageSize`, `search` mode
- Separate Create/Update/List request classes

## 4. Mapper Interface

Location: `spring-ai-alibaba-admin-server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/mapper/`

```java
package com.alibaba.cloud.ai.studio.admin.mapper;

import com.alibaba.cloud.ai.studio.admin.entity.YourEntityDO;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import java.util.List;

@Mapper
public interface YourEntityMapper {

    int insert(YourEntityDO entity);

    int update(YourEntityDO entity);

    int deleteById(@Param("id") Long id);

    YourEntityDO selectById(@Param("id") Long id);

    YourEntityDO selectByName(@Param("name") String name);

    List<YourEntityDO> selectList(@Param("search") String search,
                                   @Param("keyword") String keyword,
                                   @Param("offset") int offset,
                                   @Param("limit") int limit);

    int selectCount(@Param("search") String search,
                    @Param("keyword") String keyword);
}
```

**Conventions:**
- `@Mapper` annotation
- `@Param` for all parameters
- Return `int` for write operations (affected rows)
- Return entity for single reads
- `selectList` with `offset`/`limit` for pagination
- `selectCount` for total count

## 5. Mapper XML

Location: `spring-ai-alibaba-admin-server-start/src/main/resources/mapper/`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
        "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.alibaba.cloud.ai.studio.admin.mapper.YourEntityMapper">

    <sql id="columns">
        id, name, description, content, create_time, update_time
    </sql>

    <resultMap id="resultMap" type="com.alibaba.cloud.ai.studio.admin.entity.YourEntityDO">
        <id property="id" column="id"/>
        <result property="name" column="name"/>
        <result property="description" column="description"/>
        <result property="content" column="content"/>
        <result property="createTime" column="create_time"/>
        <result property="updateTime" column="update_time"/>
    </resultMap>

    <insert id="insert" parameterType="...YourEntityDO" useGeneratedKeys="true" keyProperty="id">
        INSERT INTO your_table (name, description, content, create_time, update_time)
        VALUES (#{name}, #{description}, #{content}, NOW(), NOW())
    </insert>

    <update id="update" parameterType="...YourEntityDO">
        UPDATE your_table
        <set>
            <if test="name != null">name = #{name},</if>
            <if test="description != null">description = #{description},</if>
            <if test="content != null">content = #{content},</if>
            update_time = NOW()
        </set>
        WHERE id = #{id}
    </update>

    <delete id="deleteById">
        DELETE FROM your_table WHERE id = #{id}
    </delete>

    <select id="selectById" resultMap="resultMap">
        SELECT <include refid="columns"/> FROM your_table WHERE id = #{id}
    </select>

    <select id="selectByName" resultMap="resultMap">
        SELECT <include refid="columns"/> FROM your_table WHERE name = #{name}
    </select>

    <select id="selectList" resultMap="resultMap">
        SELECT <include refid="columns"/> FROM your_table
        WHERE 1=1
        <if test="keyword != null and keyword != ''">
            <choose>
                <when test="search == 'accurate'">
                    AND name = #{keyword}
                </when>
                <otherwise>
                    AND name LIKE CONCAT('%', #{keyword}, '%')
                </otherwise>
            </choose>
        </if>
        ORDER BY create_time DESC
        LIMIT #{offset}, #{limit}
    </select>

    <select id="selectCount" resultType="int">
        SELECT COUNT(*) FROM your_table
        WHERE 1=1
        <if test="keyword != null and keyword != ''">
            <choose>
                <when test="search == 'accurate'">
                    AND name = #{keyword}
                </when>
                <otherwise>
                    AND name LIKE CONCAT('%', #{keyword}, '%')
                </otherwise>
            </choose>
        </if>
    </select>

</mapper>
```

**Conventions:**
- `<sql id="columns">` for reusable column list
- `<resultMap>` for explicit mapping
- `useGeneratedKeys="true" keyProperty="id"` on insert
- Dynamic `<set>` with `<if>` for partial updates
- `NOW()` for timestamps at DB level
- Search supports `accurate` (exact) and `blur` (LIKE) modes

## 6. Service Interface

Location: `spring-ai-alibaba-admin-server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/service/`

```java
package com.alibaba.cloud.ai.studio.admin.service;

import com.alibaba.cloud.ai.studio.admin.common.PageResult;
import com.alibaba.cloud.ai.studio.admin.dto.YourEntity;
import com.alibaba.cloud.ai.studio.admin.dto.request.*;
import com.alibaba.cloud.ai.studio.admin.exception.StudioException;

public interface YourEntityService {

    YourEntity create(YourEntityCreateRequest request) throws StudioException;

    YourEntity getById(Long id) throws StudioException;

    PageResult<YourEntity> list(YourEntityListRequest request) throws StudioException;

    YourEntity update(YourEntityUpdateRequest request) throws StudioException;

    void deleteById(Long id) throws StudioException;
}
```

## 7. Service Implementation

```java
package com.alibaba.cloud.ai.studio.admin.service.impl;

import com.alibaba.cloud.ai.studio.admin.common.PageResult;
import com.alibaba.cloud.ai.studio.admin.dto.YourEntity;
import com.alibaba.cloud.ai.studio.admin.dto.request.*;
import com.alibaba.cloud.ai.studio.admin.entity.YourEntityDO;
import com.alibaba.cloud.ai.studio.admin.exception.StudioException;
import com.alibaba.cloud.ai.studio.admin.mapper.YourEntityMapper;
import com.alibaba.cloud.ai.studio.admin.service.YourEntityService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class YourEntityServiceImpl implements YourEntityService {

    private final YourEntityMapper yourEntityMapper;

    @Override
    @Transactional
    public YourEntity create(YourEntityCreateRequest request) throws StudioException {
        log.info("Creating entity: {}", request);

        // Check uniqueness
        YourEntityDO existing = yourEntityMapper.selectByName(request.getName());
        if (existing != null) {
            throw new StudioException(StudioException.CONFLICT,
                    "Name already exists: " + request.getName());
        }

        YourEntityDO entityDO = YourEntityDO.builder()
                .name(request.getName())
                .description(request.getDescription())
                .content(request.getContent())
                .build();

        yourEntityMapper.insert(entityDO);
        log.info("Entity created: id={}", entityDO.getId());

        return YourEntity.fromDO(entityDO);
    }

    @Override
    public YourEntity getById(Long id) throws StudioException {
        YourEntityDO entityDO = yourEntityMapper.selectById(id);
        if (entityDO == null) {
            throw new StudioException(StudioException.NOT_FOUND, "Entity not found: " + id);
        }
        return YourEntity.fromDO(entityDO);
    }

    @Override
    public PageResult<YourEntity> list(YourEntityListRequest request) throws StudioException {
        int offset = (request.getPageNo() - 1) * request.getPageSize();

        List<YourEntityDO> entities = yourEntityMapper.selectList(
                request.getSearch(), request.getKeyword(), offset, request.getPageSize());
        int total = yourEntityMapper.selectCount(request.getSearch(), request.getKeyword());

        List<YourEntity> dtoList = entities.stream()
                .map(YourEntity::fromDO)
                .collect(Collectors.toList());

        return new PageResult<>((long) total, (long) request.getPageNo(),
                (long) request.getPageSize(), dtoList);
    }

    @Override
    @Transactional
    public YourEntity update(YourEntityUpdateRequest request) throws StudioException {
        YourEntityDO existing = yourEntityMapper.selectById(request.getId());
        if (existing == null) {
            throw new StudioException(StudioException.NOT_FOUND, "Entity not found: " + request.getId());
        }

        YourEntityDO entityDO = YourEntityDO.builder()
                .id(request.getId())
                .name(request.getName())
                .description(request.getDescription())
                .content(request.getContent())
                .build();

        yourEntityMapper.update(entityDO);
        return getById(request.getId());
    }

    @Override
    @Transactional
    public void deleteById(Long id) throws StudioException {
        YourEntityDO existing = yourEntityMapper.selectById(id);
        if (existing == null) {
            throw new StudioException(StudioException.NOT_FOUND, "Entity not found: " + id);
        }
        yourEntityMapper.deleteById(id);
    }
}
```

**Conventions:**
- `@Slf4j @Service @RequiredArgsConstructor`
- `@Transactional` on write operations
- Check existence before update/delete → `StudioException(NOT_FOUND)`
- Check uniqueness before create → `StudioException(CONFLICT)`
- Use `@Builder` to construct DO
- Return DTO (not DO) from service methods
- `PageResult<T>` for paginated responses

## 8. Controller

Location: `spring-ai-alibaba-admin-server-start/src/main/java/com/alibaba/cloud/ai/studio/admin/controller/`

```java
package com.alibaba.cloud.ai.studio.admin.controller;

import com.alibaba.cloud.ai.studio.admin.common.PageResult;
import com.alibaba.cloud.ai.studio.admin.dto.YourEntity;
import com.alibaba.cloud.ai.studio.admin.dto.request.*;
import com.alibaba.cloud.ai.studio.admin.exception.StudioException;
import com.alibaba.cloud.ai.studio.admin.service.YourEntityService;
import com.alibaba.cloud.ai.studio.runtime.domain.Result;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class YourEntityController {

    private final YourEntityService yourEntityService;

    @PostMapping("/your-entity")
    public Result<YourEntity> create(
            @Validated @RequestBody YourEntityCreateRequest request) throws StudioException {
        log.info("Create request: {}", request);
        YourEntity entity = yourEntityService.create(request);
        return Result.success(entity);
    }

    @GetMapping("/your-entity")
    public Result<YourEntity> get(
            @RequestParam @NotBlank Long id) throws StudioException {
        log.info("Get request: id={}", id);
        YourEntity entity = yourEntityService.getById(id);
        return Result.success(entity);
    }

    @GetMapping("/your-entities")
    public Result<PageResult<YourEntity>> list(
            @Validated @ModelAttribute YourEntityListRequest request) throws StudioException {
        log.info("List request: {}", request);
        PageResult<YourEntity> result = yourEntityService.list(request);
        return Result.success(result);
    }

    @PutMapping("/your-entity")
    public Result<YourEntity> update(
            @Validated @RequestBody YourEntityUpdateRequest request) throws StudioException {
        log.info("Update request: {}", request);
        YourEntity entity = yourEntityService.update(request);
        return Result.success(entity);
    }

    @DeleteMapping("/your-entity")
    public Result<Boolean> delete(
            @RequestParam @NotBlank Long id) throws StudioException {
        log.info("Delete request: id={}", id);
        yourEntityService.deleteById(id);
        return Result.success(true);
    }
}
```

**Conventions:**
- `@Slf4j @RestController @RequestMapping("/api") @RequiredArgsConstructor`
- `@Validated @RequestBody` for POST/PUT
- `@Validated @ModelAttribute` for GET list requests
- `@RequestParam @NotBlank` for single ID lookups
- Return `Result<T>` wrapper (`com.alibaba.cloud.ai.studio.runtime.domain.Result`)
- Log every request
- Singular for single resource (`/your-entity`), plural for list (`/your-entities`)
- Thin controller: no business logic, just delegate to service

## 9. Result Wrapper

```java
// Success
return Result.success(entity);
return Result.success(true);

// Error (via StudioException)
throw new StudioException(StudioException.NOT_FOUND, "Not found");
throw new StudioException(StudioException.CONFLICT, "Already exists");
throw new StudioException(StudioException.INVALID_PARAM, "Invalid parameter");
```

## 10. SQL Migration

Location: `docker/middleware/init/mysql/admin-schema.sql`

```sql
DROP TABLE IF EXISTS your_table;
CREATE TABLE your_table
(
    id          BIGINT(20) UNSIGNED AUTO_INCREMENT NOT NULL COMMENT 'Primary Key',
    name        VARCHAR(255) NOT NULL COMMENT 'Name',
    description TEXT         DEFAULT NULL COMMENT 'Description',
    content     LONGTEXT     DEFAULT NULL COMMENT 'Content',
    create_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Create time',
    update_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                ON UPDATE CURRENT_TIMESTAMP COMMENT 'Update time',
    deleted     TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '0=normal, 1=deleted',
    PRIMARY KEY (id),
    KEY idx_deleted (deleted)
) ENGINE = InnoDB
  AUTO_INCREMENT = 10000
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Your table description';
```

## Checklist

When adding a new CRUD resource:

- [ ] Entity DO with `@Data @Builder` and proper annotations
- [ ] DTO with `static fromDO()` converter
- [ ] Create/Update/List Request DTOs with validation
- [ ] Mapper interface with `@Mapper`
- [ ] Mapper XML with `<resultMap>`, dynamic SQL, pagination
- [ ] Service interface
- [ ] Service implementation with `@Transactional`, existence/uniqueness checks
- [ ] Controller with `Result<T>` wrapper, logging
- [ ] SQL in `admin-schema.sql` or `agentscope-schema.sql`
- [ ] License header on all Java files (Apache 2.0)
