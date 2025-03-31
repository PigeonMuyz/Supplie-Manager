import SwiftUI

//
// 拓竹账号登录视图
//
struct BambuLoginView: View {
    @ObservedObject var authManager: BambuAuthManager
    @State private var account: String = ""
    @State private var password: String = ""
    @State private var verificationCode: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                if authManager.isLoggedIn {
                    Section {
                        Text("已登录账号: \(UserDefaults.standard.string(forKey: "bambu_account") ?? "未知账号")")
                        
                        Button("退出登录") {
                            authManager.logout()
                        }
                        .foregroundColor(.red)
                    }
                } else if authManager.needsVerificationCode {
                    // 验证码输入界面
                    Section(header: Text("请输入验证码")) {
                        TextField("验证码", text: $verificationCode)
                            .keyboardType(.numberPad)
                    }
                    
                    Section {
                        Button("提交验证码") {
                            Task {
                                await authManager.submitVerificationCode(code: verificationCode)
                            }
                        }
                        .disabled(verificationCode.isEmpty || authManager.isLoading)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // 常规登录界面
                    Section(header: Text("Bambu Cloud 登录")) {
                        TextField("账号", text: $account)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        SecureField("密码", text: $password)
                    }
                    
                    Section {
                        Button("登录") {
                            Task {
                                await authManager.login(account: account, password: password)
                            }
                        }
                        .disabled(account.isEmpty || password.isEmpty || authManager.isLoading)
                        .frame(maxWidth: .infinity)
                    }
                }
                
                if let errorMessage = authManager.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Bambu Cloud")
            .disabled(authManager.isLoading)
            .overlay(
                Group {
                    if authManager.isLoading {
                        ProgressView("加载中...")
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authManager.isLoggedIn {
                        Button("完成") {
                            dismiss()
                        }
                    } else {
                        Button("取消") {
                            dismiss()
                        }
                    }
                }
            }
            .onDisappear {
                // 确保任何错误消息在下次展示时被清除
                if authManager.errorMessage != nil {
                    authManager.errorMessage = nil
                }
            }
        }
    }
}

#Preview {
    BambuLoginView(authManager: BambuAuthManager())
}
