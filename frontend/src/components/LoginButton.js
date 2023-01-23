import { useAuth0 } from "@auth0/auth0-react";

const LoginButton = () => {
    const { loginWithRedirect, isAuthenticated } = useAuth0();
    return (
        !isAuthenticated && (
            <button className="button" style={{width: 100, fontSize: 10, maxHeight: 20}} onClick={() => loginWithRedirect()}>
                Sign In/Register
            </button>
        )

    )
}

export default LoginButton