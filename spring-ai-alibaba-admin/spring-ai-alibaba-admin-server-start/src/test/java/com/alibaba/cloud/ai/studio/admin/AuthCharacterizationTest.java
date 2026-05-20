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

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.http.*;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Characterization Test — 登录鉴权链路
 *
 * 直接测试已运行的应用（localhost:8081），不启动 Spring Context。
 * 断言基于 2026-05-17 实际运行结果，不是"应该是什么"。
 *
 * 前置条件：应用必须已启动（bash scripts/deps-start.sh + java -jar ...）
 */
class AuthCharacterizationTest {

	private static final String BASE = System.getenv().getOrDefault("TEST_BASE_URL", "http://localhost:8081");

	private static RestTemplate rest;

	@BeforeAll
	static void setUp() {
		rest = new RestTemplate();
	}

	// ── 正确密码登录 ────────────────────────────────

	@Test
	@SuppressWarnings("unchecked")
	void login_correctPassword_returns200WithTokens() {
		HttpHeaders headers = new HttpHeaders();
		headers.setContentType(MediaType.APPLICATION_JSON);

		String body = """
				{"username":"saa","password":"123456"}
				""";
		HttpEntity<String> request = new HttpEntity<>(body, headers);

		ResponseEntity<Map> response = rest.postForEntity(
				BASE + "/console/v1/auth/login", request, Map.class);

		assertEquals(HttpStatus.OK, response.getStatusCode());

		Map<String, Object> json = response.getBody();
		assertNotNull(json);
		// code 是 String "200"，不是 Integer 200
		assertEquals("200", String.valueOf(json.get("code")));
		assertEquals("success", json.get("message"));

		Map<String, Object> data = (Map<String, Object>) json.get("data");
		assertNotNull(data);
		assertNotNull(data.get("access_token"), "access_token should not be null");
		assertNotNull(data.get("refresh_token"), "refresh_token should not be null");
		assertNotNull(data.get("expires_in"), "expires_in should not be null");

		// access_token 是 JWT 格式（三段 base64 用 . 分隔）
		String token = (String) data.get("access_token");
		assertEquals(2, token.chars().filter(c -> c == '.').count(),
				"JWT token should have 3 parts separated by dots");
	}

	// ── 错误密码登录 ────────────────────────────────

	@Test
	void login_wrongPassword_returns401() {
		HttpHeaders headers = new HttpHeaders();
		headers.setContentType(MediaType.APPLICATION_JSON);

		String body = """
				{"username":"saa","password":"wrong"}
				""";
		HttpEntity<String> request = new HttpEntity<>(body, headers);

		// 实际行为：RestTemplate 收到 HTTP 401 并抛出 HttpClientErrorException
		assertThrows(HttpClientErrorException.Unauthorized.class, () ->
				rest.postForEntity(BASE + "/console/v1/auth/login", request, Map.class));
	}

	// ── 不存在的用户 ────────────────────────────────

	@Test
	void login_nonexistentUser_returns401() {
		HttpHeaders headers = new HttpHeaders();
		headers.setContentType(MediaType.APPLICATION_JSON);

		String body = """
				{"username":"nonexistent","password":"123456"}
				""";
		HttpEntity<String> request = new HttpEntity<>(body, headers);

		// 实际行为：与错误密码相同，返回 HTTP 401，不泄露用户是否存在
		assertThrows(HttpClientErrorException.Unauthorized.class, () ->
				rest.postForEntity(BASE + "/console/v1/auth/login", request, Map.class));
	}

	// ── 空用户名 ────────────────────────────────────

	@Test
	void login_emptyUsername_returns500() {
		HttpHeaders headers = new HttpHeaders();
		headers.setContentType(MediaType.APPLICATION_JSON);

		String body = """
				{"username":"","password":"123456"}
				""";
		HttpEntity<String> request = new HttpEntity<>(body, headers);

		// 实际行为：BizException 被全局异常处理捕获，返回 HTTP 500
		// RestTemplate 收到 500 会抛出 HttpServerErrorException
		// 注意：这个行为可能是个 bug（应该返回 400），但 Characterization Test 记录的是"实际是什么"
		assertThrows(HttpServerErrorException.InternalServerError.class, () ->
				rest.postForEntity(BASE + "/console/v1/auth/login", request, Map.class));
	}

	// ── 无 Token 访问受保护接口 ─────────────────────

	@Test
	void profile_noToken_returns401() {
		assertThrows(HttpClientErrorException.Unauthorized.class, () ->
				rest.getForEntity(BASE + "/console/v1/accounts/profile", Map.class));
	}

	// ── 有效 Token 访问 profile ─────────────────────

	@Test
	@SuppressWarnings("unchecked")
	void profile_validToken_returns200WithAccountInfo() {
		// 先登录获取 Token
		String token = loginAndGetToken();

		HttpHeaders headers = new HttpHeaders();
		headers.setBearerAuth(token);
		HttpEntity<Void> request = new HttpEntity<>(headers);

		ResponseEntity<Map> response = rest.exchange(
				BASE + "/console/v1/accounts/profile", HttpMethod.GET, request, Map.class);

		assertEquals(HttpStatus.OK, response.getStatusCode());

		Map<String, Object> json = response.getBody();
		assertNotNull(json);
		assertEquals("200", String.valueOf(json.get("code")));
		assertEquals("success", json.get("message"));

		Map<String, Object> data = (Map<String, Object>) json.get("data");
		assertNotNull(data);
		assertEquals("saa", data.get("username"));
		assertEquals("10000", data.get("account_id"));
		assertEquals("admin", data.get("type"));
		assertEquals("normal", data.get("status"));
		assertNotNull(data.get("default_workspace_id"));
	}

	// ── 无效 Token 访问 profile ─────────────────────

	@Test
	void profile_invalidToken_returns401() {
		HttpHeaders headers = new HttpHeaders();
		headers.setBearerAuth("invalid.token.here");
		HttpEntity<Void> request = new HttpEntity<>(headers);

		assertThrows(HttpClientErrorException.Unauthorized.class, () ->
				rest.exchange(
						BASE + "/console/v1/accounts/profile", HttpMethod.GET, request, Map.class));
	}

	// ── 辅助方法 ────────────────────────────────────

	@SuppressWarnings("unchecked")
	private String loginAndGetToken() {
		HttpHeaders headers = new HttpHeaders();
		headers.setContentType(MediaType.APPLICATION_JSON);

		String body = """
				{"username":"saa","password":"123456"}
				""";
		HttpEntity<String> request = new HttpEntity<>(body, headers);

		ResponseEntity<Map> response = rest.postForEntity(
				BASE + "/console/v1/auth/login", request, Map.class);

		Map<String, Object> data = (Map<String, Object>) response.getBody().get("data");
		return (String) data.get("access_token");
	}
}
