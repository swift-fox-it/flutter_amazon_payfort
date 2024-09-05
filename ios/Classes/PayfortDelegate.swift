import Flutter
import PayFortSDK
import CommonCrypto
import PassKit

public class PayFortDelegate: NSObject, PKPaymentAuthorizationViewControllerDelegate {
    
    private var payFort: PayFortController? = nil
    
    private var options: PayFortOptions? = nil
    
    private var channel: FlutterMethodChannel? = nil
    
    private var requestData : Dictionary<String, Any>?
    private var viewController : UIViewController?
    
    
    func initialize(options: PayFortOptions, channel: FlutterMethodChannel){
        self.options = options
        self.channel = channel
        let environment = getEnvironment(environment: self.options?.environment)
        payFort = PayFortController.init(enviroment: environment)
    }
    
    public func getEnvironment(environment :String?) -> PayFortEnviroment {
        switch (environment) {
        case ("test"):
            return PayFortEnviroment.sandBox
        case ("production"):
            return PayFortEnviroment.production
        default:
            return PayFortEnviroment.sandBox
        }
    }
    
    public func callPayFort(requestData : Dictionary<String, Any>, viewController : UIViewController){
        
        var request = [String : String]()
        request["command"] = (requestData["command"] as? String) ?? "";
        request["customer_name"] = (requestData["customer_name"] as? String) ?? "";
        request["customer_email"] = (requestData["customer_email"] as? String) ?? "";
        request["currency"] = (requestData["currency"] as? String) ?? "";
        request["amount"] = (requestData["amount"] as? String) ?? "";
        request["language"] = (requestData["language"] as? String) ?? "";
        request["order_description"] = (requestData["order_description"] as? String) ?? "";
        request["sdk_token"] = (requestData["sdk_token"] as? String) ?? "";
        request["customer_ip"] = (requestData["customer_ip"] as? String) ?? "";
        request["merchant_reference"] = (requestData["merchant_reference"] as? String) ?? "";

        if let paymentOption = requestData["payment_option"] as? String {
            request["payment_option"] = paymentOption;
        }

        if let eci = requestData["eci"] as? String {
            request["eci"] = eci;
        }

        if let tokenName = requestData["token_name"] as? String {
            request["token_name"] = tokenName;
        }

        if let phoneNumber = requestData["phone_number"] as? String {
            request["phone_number"] = phoneNumber;
        }


        payFort?.hideLoading = options?.hideLoading ?? false
        payFort?.presentAsDefault = options?.presentAsDefault ?? true
        payFort?.isShowResponsePage = options?.isShowResponsePage ?? true

        payFort?.callPayFort(
            withRequest: request,
            currentViewController: viewController,
            success: { requestDic, responeDic in

                print("succeeded: - \(requestDic) - \(responeDic)")
                self.channel?.invokeMethod("succeeded", arguments: responeDic)
                return

            },
            canceled: { requestDic, responeDic in

                print("cancelled: - \(requestDic) -  \(responeDic)")
                self.channel?.invokeMethod("cancelled", arguments: nil)
                return

            },
            faild: { requestDic, responeDic, message in

                print("failed: \(message) - \(requestDic) - \(responeDic)")
                self.channel?.invokeMethod("failed", arguments: ["message": message])
                return

            }
        )
    }

    public func callPayFortForApplePay(requestData : Dictionary<String, Any>, viewController : UIViewController){

        self.requestData = requestData
        self.viewController = viewController

        let amount = decimal(with: (requestData["amount"] as? String) ?? "0.0")

        let paymentRequest = PKPaymentRequest()
        paymentRequest.merchantIdentifier = (requestData["apple_pay_merchant_id"] as? String) ?? "";
        if #available(iOS 12.1.1, *) {
            paymentRequest.supportedNetworks = [.visa, .masterCard, .mada, .amex]
        } else {
            paymentRequest.supportedNetworks = [.visa, .masterCard, .amex]
        };
        paymentRequest.merchantCapabilities = .capability3DS;
        paymentRequest.paymentSummaryItems = [PKPaymentSummaryItem(label: (requestData["order_description"] as? String) ?? "", amount: amount)]
        paymentRequest.countryCode = (requestData["country_code"] as? String) ?? "";
        paymentRequest.currencyCode = (requestData["currency"] as? String) ?? "";

        let applePayController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest)
        applePayController?.delegate = self
        self.viewController?.present(applePayController!, animated: true)
    }


    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {

        let asyncSuccessful = payment.token.paymentData.count != 0

        let amount = (Double((requestData?["amount"] as? String) ?? "0.0") ?? 0.0) * 100

        if asyncSuccessful {

            var request = [String : String]()
            request["digital_wallet"] = "APPLE_PAY"
            request["command"] = (requestData?["command"] as? String) ?? "";
            request["amount"] = String(amount.toInt() ?? 0);
            request["currency"] = (requestData?["currency"] as? String) ?? "";
            request["language"] = (requestData?["language"] as? String) ?? "";
            request["customer_email"] = (requestData?["customer_email"] as? String) ?? "";
            request["sdk_token"] = (requestData?["sdk_token"] as? String) ?? "";
            request["customer_ip"] = (requestData?["customer_ip"] as? String) ?? "";
            request["customer_name"] = (requestData?["customer_name"] as? String) ?? "";
            request["order_description"] = (requestData?["order_description"] as? String) ?? "";
            request["merchant_reference"] = (requestData?["merchant_reference"] as? String) ?? "";

            if let paymentOption = requestData?["payment_option"] as? String {
                request["payment_option"] = paymentOption;
            }
            
            if let eci = requestData?["eci"] as? String {
                request["eci"] = eci;
            }
            
            if let tokenName = requestData?["token_name"] as? String {
                request["token_name"] = tokenName;
            }
            
            if let phoneNumber = requestData?["phone_number"] as? String {
                request["phone_number"] = phoneNumber;
            }
            
            
            payFort?.hideLoading = options?.hideLoading ?? false
            payFort?.presentAsDefault = options?.presentAsDefault ?? true
            payFort?.isShowResponsePage = options?.isShowResponsePage ?? true
            
            print("Request Payfort :\(request)")
            
            
            payFort?.callPayFortForApplePay(
                withRequest: request,
                applePayPayment: payment,
                currentViewController: viewController!,
                success: { requestDic, responeDic in
                    
                    print("succeeded: - \(requestDic) - \(responeDic)")
                    completion(.success)
                    self.channel?.invokeMethod("apple_pay_succeeded", arguments: responeDic)
                    return
                    
                },
                faild: { requestDic, responeDic, message in
                    
                    print("failed: \(message) - \(requestDic) - \(responeDic)")
                    completion(.failure)
                    self.channel?.invokeMethod("apple_pay_failed", arguments: ["message": message])
                    return
                    
                })
        } else {
            
            print("asyncSuccessful: \(asyncSuccessful)")
            completion(.failure)
            self.channel?.invokeMethod("apple_pay_failed", arguments: ["message": "Something went wrong"])
        }
        
    }
    
    public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        requestData = nil
        viewController = nil
        controller.dismiss(animated: true)
    }
    
    
    public func getUDID() -> String? {
        return payFort?.getUDID()
    }
    
    
    public func generateSignature(concatenatedString : String?) -> String {
        let data = ccSha256(data: concatenatedString?.data(using: .utf8))
        let signature = data.map { String(format: "%02hhx", $0) }.joined()
        return signature
    }
    
    
    func ccSha256(data: Data?) -> Data {
        var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        
        _ = digest.withUnsafeMutableBytes({ digestBytes in
            data?.withUnsafeBytes({ stringBytes in
                CC_SHA256(stringBytes, CC_LONG(data?.count ?? 0), digestBytes)
            })
        })
        return digest
    }
    
    
    private func decimal(with string: String) -> NSDecimalNumber {
        let formatter = NumberFormatter()
        formatter.generatesDecimalNumbers = true
        let amount = formatter.number(from: string) as? NSDecimalNumber ?? 0
        return amount;
    }
    
}


extension Double {
    
    func toInt() -> Int? {
        let roundedValue = rounded(.toNearestOrEven)
        return Int(exactly: roundedValue)
    }
}

