import Foundation

enum HandShakeState {
    case await_np_hello
    case await_ep_hello
    case await_auth
    case done
}
