import Foundation

// 登录请求体
struct LoginRequest: Codable {
    var account: String
    var password: String?
    var code: String?
    var apiError: String?
    
    init(account: String, password: String) {
        self.account = account
        self.password = password
        self.apiError = ""
    }
    
    init(account: String, code: String) {
        self.account = account
        self.code = code
    }
}

// 登录响应体
struct LoginResponse: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresIn: Int
    var refreshExpiresIn: Int
    var tfaKey: String
    var accessMethod: String
    var loginType: String
}

// 认证状态管理
class BambuAuthManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var needsVerificationCode = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var account: String = ""
    private var currentToken: String?
    private var refreshToken: String?
    private var tokenExpiration: Date?
    
    // UserDefaults keys
    private let tokenKey = "bambu_access_token"
    private let refreshTokenKey = "bambu_refresh_token"
    private let tokenExpirationKey = "bambu_token_expiration"
    private let accountKey = "bambu_account"
    
    init() {
        loadAuthData()
    }
    
    // 从本地存储加载授权数据
    private func loadAuthData() {
        if let token = UserDefaults.standard.string(forKey: tokenKey),
           let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey),
           let expirationDate = UserDefaults.standard.object(forKey: tokenExpirationKey) as? Date,
           let savedAccount = UserDefaults.standard.string(forKey: accountKey) {
            
            self.currentToken = token
            self.refreshToken = refreshToken
            self.tokenExpiration = expirationDate
            self.account = savedAccount
            
            // 检查token是否过期
            if expirationDate > Date() {
                self.isLoggedIn = true
            } else {
                // Token 已过期，需要刷新或重新登录
                // TODO: 实现刷新 token 的功能
                self.isLoggedIn = false
            }
        }
    }
    
    // 保存授权数据到本地存储
    private func saveAuthData(token: String, refreshToken: String, expiresIn: Int, account: String) {
        self.currentToken = token
        self.refreshToken = refreshToken
        
        // 计算过期时间
        let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        self.tokenExpiration = expirationDate
        self.account = account
        
        // 保存到 UserDefaults
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        UserDefaults.standard.set(expirationDate, forKey: tokenExpirationKey)
        UserDefaults.standard.set(account, forKey: accountKey)
    }
    
    // 登录请求
    func login(account: String, password: String) async {
        self.account = account
        await performLogin(LoginRequest(account: account, password: password))
    }
    
    // 提交验证码
    func submitVerificationCode(code: String) async {
        await performLogin(LoginRequest(account: account, code: code))
    }
    
    // 执行登录请求
    private func performLogin(_ request: LoginRequest) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let url = URL(string: "https://api.bambulab.cn/v1/user-service/user/login") else {
            DispatchQueue.main.async {
                self.errorMessage = "无效的URL"
                self.isLoading = false
            }
            return
        }
        
        do {
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.errorMessage = "无效的响应"
                    self.isLoading = false
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                    
                    DispatchQueue.main.async {
                        if loginResponse.loginType == "verifyCode" {
                            // 需要验证码
                            self.needsVerificationCode = true
                        } else {
                            // 登录成功
                            self.needsVerificationCode = false
                            self.isLoggedIn = true
                            self.saveAuthData(
                                token: loginResponse.accessToken,
                                refreshToken: loginResponse.refreshToken,
                                expiresIn: loginResponse.expiresIn,
                                account: self.account
                            )
                        }
                        self.isLoading = false
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "解析响应失败: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            } else {
                // 处理错误响应
                let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                DispatchQueue.main.async {
                    self.errorMessage = "请求失败: \(httpResponse.statusCode), \(responseString)"
                    self.isLoading = false
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "请求失败: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // 登出
    func logout() {
        isLoggedIn = false
        currentToken = nil
        refreshToken = nil
        tokenExpiration = nil
        
        // 清除存储的凭证
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpirationKey)
        UserDefaults.standard.removeObject(forKey: accountKey)
    }
    
    // 获取当前的访问令牌
    func getAccessToken() -> String? {
        return currentToken
    }
}
