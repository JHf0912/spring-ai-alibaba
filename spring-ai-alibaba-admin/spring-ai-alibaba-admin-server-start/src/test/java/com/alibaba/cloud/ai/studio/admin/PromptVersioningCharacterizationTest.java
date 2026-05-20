/*
 * Copyright 2025-2026 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.alibaba.cloud.ai.studio.admin;

import org.junit.jupiter.api.*;
import org.springframework.http.*;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Characterization Test — Prompt 版本化链路
 *
 * 记录「主表 + 版本表」模式的当前真实行为。
 * 断言基于 2026-05-17 实际运行结果，不是"应该是什么"。
 *
 * 前置条件：应用必须已启动（localhost:8081）
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class PromptVersioningCharacterizationTest {

	private static final String BASE = System.getenv().getOrDefault("TEST_BASE_URL", "http://localhost:8081");
	private static final String PK = "test-char-prompt-" + System.currentTimeMillis();

	private static RestTemplate rest;

	@BeforeAll
	static void setUp() {
		rest = new RestTemplate();
	}

	@AfterAll
	static void tearDown() {
		// 清理测试数据
		try {
			HttpHeaders h = new HttpHeaders();
			h.setContentType(MediaType.APPLICATION_JSON);
			rest.exchange(BASE + "/api/prompt?promptKey=" + PK, HttpMethod.DELETE, null, Map.class);
		}
		catch (Exception ignored) {
		}
	}

	// ── 创建 Prompt 后不自动创建版本 ─────────────────

	@Test
	@Order(1)
	@SuppressWarnings("unchecked")
	void createPrompt_doesNotAutoCreateVersion() {
		// 创建 Prompt
		ResponseEntity<Map> resp = createPrompt(PK, "测试", "你好{{name}}", "name");
		assertEquals(HttpStatus.OK, resp.getStatusCode());
		assertEquals("200", String.valueOf(resp.getBody().get("code")));

		// 查询版本列表 — 应为空
		ResponseEntity<Map> verResp = rest.getForEntity(
				BASE + "/api/prompt/versions?promptKey=" + PK, Map.class);
		assertEquals(HttpStatus.OK, verResp.getStatusCode());

		Map<String, Object> data = (Map<String, Object>) verResp.getBody().get("data");
		assertEquals("0", String.valueOf(data.get("totalCount")));

		// 查询 Prompt 详情 — latestVersion 应为 null
		ResponseEntity<Map> detailResp = rest.getForEntity(
				BASE + "/api/prompt?promptKey=" + PK, Map.class);
		Map<String, Object> detail = (Map<String, Object>) detailResp.getBody().get("data");
		// 实际行为：latestVersion 是空字符串，不是 null
		assertTrue(detail.get("latestVersion") == null || "".equals(detail.get("latestVersion")),
				"创建 Prompt 后 latestVersion 应为 null 或空字符串，实际: " + detail.get("latestVersion"));
	}

	// ── 创建版本 → latest_version 更新 ───────────────

	@Test
	@Order(2)
	@SuppressWarnings("unchecked")
	void createVersion_updatesLatestVersion() {
		// 创建版本 0.0.1
		ResponseEntity<Map> v1 = createVersion(PK, "0.0.1", "v1", "", "第一版");
		assertEquals("200", String.valueOf(v1.getBody().get("code")));

		Map<String, Object> v1Data = (Map<String, Object>) v1.getBody().get("data");
		assertEquals("0.0.1", v1Data.get("version"));
		assertEquals("pre", v1Data.get("status"));

		// 创建版本 0.0.2
		ResponseEntity<Map> v2 = createVersion(PK, "0.0.2", "v2", "", "第二版");
		assertEquals("200", String.valueOf(v2.getBody().get("code")));

		// 查询 Prompt 详情 — latestVersion 应为 0.0.2
		ResponseEntity<Map> detailResp = rest.getForEntity(
				BASE + "/api/prompt?promptKey=" + PK, Map.class);
		Map<String, Object> detail = (Map<String, Object>) detailResp.getBody().get("data");
		assertEquals("0.0.2", detail.get("latestVersion"));
		assertEquals("pre", detail.get("latestVersionStatus"));
	}

	// ── 旧版本数据不丢 ──────────────────────────────

	@Test
	@Order(3)
	@SuppressWarnings("unchecked")
	void createNewVersion_preservesOldVersion() {
		// 查询版本列表 — 应有 2 个版本
		ResponseEntity<Map> verResp = rest.getForEntity(
				BASE + "/api/prompt/versions?promptKey=" + PK, Map.class);
		Map<String, Object> data = (Map<String, Object>) verResp.getBody().get("data");
		assertEquals("2", String.valueOf(data.get("totalCount")));

		// 查询 0.0.1 版本详情 — 应仍存在
		ResponseEntity<Map> v1Detail = rest.getForEntity(
				BASE + "/api/prompt/version?promptKey=" + PK + "&version=0.0.1", Map.class);
		assertEquals(HttpStatus.OK, v1Detail.getStatusCode());

		Map<String, Object> v1Data = (Map<String, Object>) v1Detail.getBody().get("data");
		assertEquals("0.0.1", v1Data.get("version"));
		assertEquals("v1", v1Data.get("template"));
		assertEquals("pre", v1Data.get("status"));

		// 查询 0.0.2 版本详情 — previousVersion 应为 0.0.1
		ResponseEntity<Map> v2Detail = rest.getForEntity(
				BASE + "/api/prompt/version?promptKey=" + PK + "&version=0.0.2", Map.class);
		Map<String, Object> v2Data = (Map<String, Object>) v2Detail.getBody().get("data");
		assertEquals("0.0.2", v2Data.get("version"));
		assertEquals("0.0.1", v2Data.get("previousVersion"));
	}

	// ── 重复版本号不报错（静默覆盖）──────────────────

	@Test
	@Order(4)
	@SuppressWarnings("unchecked")
	void createDuplicateVersion_doesNotReject_silentlyOverwrites() {
		// 创建重复版本 0.0.2
		ResponseEntity<Map> dup = createVersion(PK, "0.0.2", "v2-overwritten", "", "覆盖版");
		// 实际行为：HTTP 200，不报错，静默覆盖
		assertEquals(HttpStatus.OK, dup.getStatusCode());
		assertEquals("200", String.valueOf(dup.getBody().get("code")));

		// 查询 0.0.2 — template 应为覆盖后的值
		ResponseEntity<Map> v2Detail = rest.getForEntity(
				BASE + "/api/prompt/version?promptKey=" + PK + "&version=0.0.2", Map.class);
		Map<String, Object> v2Data = (Map<String, Object>) v2Detail.getBody().get("data");
		assertEquals("v2-overwritten", v2Data.get("template"),
				"重复版本应静默覆盖旧版本的 template");
	}

	// ── 查询不存在的 Prompt → 404 ───────────────────

	@Test
	@Order(5)
	void queryNonexistentPrompt_returns404() {
		assertThrows(HttpClientErrorException.NotFound.class, () ->
				rest.getForEntity(BASE + "/api/prompt?promptKey=nonexistent-" + System.currentTimeMillis(), Map.class));
	}

	// ── 查询不存在的版本 → 404 ──────────────────────

	@Test
	@Order(6)
	void queryNonexistentVersion_returns404() {
		assertThrows(HttpClientErrorException.NotFound.class, () ->
				rest.getForEntity(BASE + "/api/prompt/version?promptKey=" + PK + "&version=9.9.9", Map.class));
	}

	// ── 删除 Prompt → 200 ───────────────────────────

	@Test
	@Order(7)
	@SuppressWarnings("unchecked")
	void deletePrompt_returns200() {
		// 先创建一个临时 Prompt
		String tmpPk = PK + "-to-delete";
		createPrompt(tmpPk, "临时", "hello", "");

		// 删除
		HttpHeaders h = new HttpHeaders();
		h.setContentType(MediaType.APPLICATION_JSON);
		ResponseEntity<Map> resp = rest.exchange(
				BASE + "/api/prompt?promptKey=" + tmpPk, HttpMethod.DELETE, null, Map.class);
		assertEquals(HttpStatus.OK, resp.getStatusCode());
		assertEquals("200", String.valueOf(resp.getBody().get("code")));
		assertEquals("true", String.valueOf(resp.getBody().get("data")));
	}

	// ── 辅助方法 ────────────────────────────────────

	@SuppressWarnings("unchecked")
	private ResponseEntity<Map> createPrompt(String key, String desc, String template, String variables) {
		HttpHeaders h = new HttpHeaders();
		h.setContentType(MediaType.APPLICATION_JSON);
		String body = String.format("""
				{"promptKey":"%s","promptDesc":"%s","template":"%s","variables":"%s"}
				""", key, desc, template, variables);
		return rest.postForEntity(BASE + "/api/prompt", new HttpEntity<>(body, h), Map.class);
	}

	@SuppressWarnings("unchecked")
	private ResponseEntity<Map> createVersion(String key, String version, String template, String variables, String desc) {
		HttpHeaders h = new HttpHeaders();
		h.setContentType(MediaType.APPLICATION_JSON);
		String body = String.format("""
				{"promptKey":"%s","version":"%s","template":"%s","variables":"%s","versionDesc":"%s"}
				""", key, version, template, variables, desc);
		return rest.postForEntity(BASE + "/api/prompt/version", new HttpEntity<>(body, h), Map.class);
	}
}
