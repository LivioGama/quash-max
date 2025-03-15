import { baseURL } from "@/app/apis/api-config";
import axios from "axios";
import CredentialsProvider from "next-auth/providers/credentials";
import GoogleProvider from "next-auth/providers/google";
import { signOut } from "next-auth/react";

export const refreshBaseURL = process.env.NEXT_PUBLIC_REFRESH_BASE_URL;
const googleClientId = process.env.GOOGLE_CLIENT_ID as string;
const googleClientSecret = process.env.GOOGLE_CLIENT_SECRET as string;

// if (!googleClientId || !googleClientSecret) {
//   throw new Error("Missing Google client ID or secret");
// }

export const fetchFreshTokens = async (refreshAccessToken: any) => {
  console.log("Attempting to refresh tokens with provided refresh token.");
  try {
    const response = await axios.get(
      `${refreshBaseURL}api/auth/get-refresh-token`,
      {
        params: {
          refreshToken: refreshAccessToken,
        },
      },
    );

    // Check if the response is valid and contains the required tokens
    if (response.status === 200 && response.data && response.data.data) {
      const { token, refreshToken } = response.data.data;
      if (token && refreshToken) {
        console.log("Tokens refreshed successfully.");
        return { token, refreshToken };
      } else {
        throw new Error("Response missing tokens");
      }
    } else {
      throw new Error("Failed to refresh tokens due to invalid response");
    }
  } catch (error: any) {
    console.error("Error refreshing tokens:", error);
    await signOut();
    throw new Error(
      `Error fetching new tokens: ${error.message || error.toString()}`,
    );
  }
};

const isTokenExpired = (token: string) => {
  try {
    const parts = token.split(".");
    const payload = JSON.parse(atob(parts[1]));
    const expirationTime = payload.exp * 1000;
    return Date.now() > expirationTime;
  } catch (error) {
    console.error("Error checking token expiration:", error);
    return false;
  }
};

export const authOptions = {
  providers: [
    CredentialsProvider({
      name: "Credentials",
      credentials: {
        email: {
          label: "Email",
          type: "email",
          placeholder: "johndoe@email.com",
        },
        password: { label: "Password", type: "password" },
      },
      async authorize(credentials) {
        try {
          console.log(
            "NextAuth authorize called with email:",
            credentials?.email,
          );

          // Check if credentials exist
          if (!credentials?.email || !credentials?.password) {
            console.error("Missing email or password in credentials");
            return Promise.reject(
              new Error(
                JSON.stringify({
                  errors: {
                    message: "Email and password are required",
                  },
                  status: false,
                }),
              ),
            );
          }

          const res = await getUserData(credentials);
          console.log("User data retrieved successfully in authorize");

          return {
            ...credentials,
            data: res,
          } as any;
        } catch (error: any) {
          console.error(
            "Authentication error:",
            error?.response?.data || error?.message || error,
          );

          let errorMessage = "Authentication failed";
          if (error?.response?.data?.message) {
            errorMessage = error.response.data.message;
          } else if (error?.response?.data) {
            errorMessage = error.response.data;
          } else if (error?.message) {
            errorMessage = error.message;
          }

          return Promise.reject(
            new Error(
              JSON.stringify({
                errors: {
                  message: errorMessage,
                },
                status: false,
              }),
            ),
          );
        }
      },
    }),
    GoogleProvider({
      clientId: googleClientId,
      clientSecret: googleClientSecret,
    }),
  ],
  secret: process.env.NEXTAUTH_SECRET,
  callbacks: {
    async signIn({ account }: any) {
      if (account.provider === "google") {
        try {
          return true;
        } catch (error: any) {
          console.error(
            "Google sign-in error:",
            error?.response?.data || error?.message || error,
          );

          let errorMessage = "Google authentication failed";
          if (error?.response?.data?.message) {
            errorMessage = error.response.data.message;
          } else if (error?.response?.data) {
            errorMessage = error.response.data;
          } else if (error?.message) {
            errorMessage = error.message;
          }

          return Promise.reject(
            new Error(
              JSON.stringify({
                errors: {
                  message: errorMessage,
                },
                status: false,
              }),
            ),
          );
        }
      }

      return true;
    },
    jwt: async ({ token, user, trigger, session, account }: any) => {
      // Attempt to refresh token if it's expired
      const accessToken = token?.data?.token;
      if (accessToken && isTokenExpired(accessToken)) {
        try {
          const response = await fetchFreshTokens(token?.data?.refreshToken);
          if (!response || !response.token || !response.refreshToken) {
            throw new Error("Failed to refresh tokens");
          }
          return {
            ...token,
            data: {
              ...token.data,
              token: response.token,
              refreshToken: response.refreshToken,
            },
          };
        } catch (error) {
          console.error("JWT refresh token error:", error);
        }
      }
      if (trigger === "update") {
        return {
          ...token,

          data: {
            ...token.data,
            isVerified: session.user.isVerified,
            shouldNavigateToDashboard: session.user.shouldNavigateToDashboard,
            fullName: session.user.fullName,
          },
        };
      }
      // If new user data is present (e.g., during sign-in or token refresh), update the token's data
      if (account?.provider === "google") {
        const code: string = await account.access_token;

        try {
          const res = await axios.get(
            `${baseURL}/api/auth/google/authorize?code=${code}`,
            {
              headers: {
                "Content-Type": "application/json",
              },
            },
          );

          const response = {
            shouldNavigateToDashboard:
              res?.data.data.should_navigate_to_dashboard,
            token: res?.data.data.token,
            refreshToken: res?.data.data.refreshToken,
            isVerified: true,
            isOrganizationPresent: res?.data.data.organisation_present,
          };

          if (user) {
            return {
              ...token,
              data: response,
            };
          }

          // call Google authorization API
          return true;
        } catch (error: any) {
          console.error(
            "Google authorization error:",
            error?.response?.data || error?.message || error,
          );

          let errorMessage = "Google authorization failed";
          if (error?.response?.data?.message) {
            errorMessage = error.response.data.message;
          } else if (error?.response?.data) {
            errorMessage = error.response.data;
          } else if (error?.message) {
            errorMessage = error.message;
          }

          return Promise.reject(
            new Error(
              JSON.stringify({
                errors: {
                  message: errorMessage,
                },
                status: false,
              }),
            ),
          );
        }
      } else {
        if (user) {
          return {
            ...token,
            data: user.data,
          };
        }
        return token;
      }
    },
    session: async ({ session, token }: any) => {
      if (token) {
        session.data = token.data;
        session.isVerified = token?.isVerified;
        session.user.isVerified = token?.data?.isVerified || false;
        session.user.shouldNavigateToDashboard =
          token.data.shouldNavigateToDashboard;
        session.user.fullName = token?.data?.fullName || "";
        session.user.isOrganizationPresent =
          token?.data?.isOrganizationPresent || false;
      }
      return session;
    },
  },
  pages: {
    signIn: "/",
    error: "/",
  },
};

export const verifyApp = async (token: string, orgToken: string) => {
  try {
    console.log("Attempting app verification with token:", orgToken);
    const verifyResponse = await axios({
      method: "GET",
      url: `${baseURL}/api/app/verify-app`,
      params: { orgToken },
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
    });
    console.log("App verification response:", verifyResponse.status);
    return { success: true, status: verifyResponse.status };
  } catch (error: any) {
    console.warn("App verification failed:", {
      status: error?.response?.status,
      data: error?.response?.data,
      message: error?.message,
    });
    return {
      success: false,
      status: error?.response?.status,
      message: error?.message,
    };
  }
};

export const verifyAppDirect = async (token: string, orgToken: string) => {
  console.log("Direct verify app call with token:", token);
  console.log("orgToken:", orgToken);

  // Create a dedicated axios instance for this specific call
  const directAxios = axios.create({
    baseURL: baseURL,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
      // Set the Origin header to match what the server expects
      Origin: "http://localhost:3000",
    },
    // Important for CORS with credentials
    withCredentials: true,
  });

  // Add request logging interceptor
  directAxios.interceptors.request.use((request) => {
    console.log("Request URL:", request.url);
    console.log("Request Headers:", request.headers);
    console.log("Request Params:", request.params);
    return request;
  });

  // Add response logging interceptor
  directAxios.interceptors.response.use(
    (response) => {
      console.log("Response Status:", response.status);
      console.log("Response Data:", response.data);
      return response;
    },
    (error) => {
      console.error("Error Response:", error.response?.status);
      console.error("Error Data:", error.response?.data);
      console.error("Error Message:", error.message);
      return Promise.reject(error);
    },
  );

  try {
    // Approach 1: Using Origin header with specific port
    try {
      const response1 = await axios({
        method: "GET",
        url: `${baseURL}/api/app/verify-app`,
        params: { orgToken },
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          Accept: "application/json",
          Origin: "http://localhost:3000",
        },
        withCredentials: true,
      });
      console.log("Approach 1 succeeded");
      return { success: true, data: response1.data };
    } catch (error1) {
      console.log("Approach 1 failed, trying approach 2");
    }

    // Approach 2: Using direct URL with no params
    try {
      const response2 = await directAxios.get(
        `/api/app/verify-app?orgToken=${encodeURIComponent(orgToken)}`,
      );
      console.log("Approach 2 succeeded");
      return { success: true, data: response2.data };
    } catch (error2) {
      console.log("Approach 2 failed, trying approach 3");
    }

    // Approach 3: Using proxy approach to bypass CORS
    try {
      // Try using a proxy approach
      const response3 = await fetch(
        `${baseURL}/api/app/verify-app?orgToken=${encodeURIComponent(orgToken)}`,
        {
          method: "GET",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
            Origin: "http://localhost:3000",
          },
          credentials: "include",
        },
      );

      if (response3.ok) {
        const data = await response3.json();
        console.log("Approach 3 succeeded");
        return { success: true, data };
      } else {
        throw new Error(`Fetch failed with status: ${response3.status}`);
      }
    } catch (error3) {
      console.log("All approaches failed");
      throw error3;
    }
  } catch (error) {
    console.error("Verification failed:", error.message);
    return {
      success: false,
      error: error.message,
      response: error.response?.data,
    };
  }
};

async function getUserData(credentials: any) {
  console.log("Attempting authentication for email:", credentials?.email);

  const payload = {
    workEmail: credentials?.email,
    password: credentials?.password,
  };

  try {
    const user = await axios.post(`${baseURL}/api/auth/signin`, payload, {
      headers: { "Content-Type": "application/json" },
    });

    console.log("Authentication successful, response status:", user.status);
    console.log("Login response:", JSON.stringify(user.data));

    const authToken = user?.data?.data?.token;
    const orgToken = user?.data?.data?.orgToken;

    // User verified APIs
    let isVerified = false;
    try {
      const isVerifiedDataRes = await axios.get(
        `${baseURL}/api/users/is_verified`,
        {
          headers: { Authorization: `Bearer ${authToken}` },
        },
      );
      isVerified = isVerifiedDataRes?.data?.data;
    } catch (verifyError: any) {
      console.warn("Failed to get verification status:", verifyError?.message);
      // Continue with isVerified as false
    }

    // get user data
    let fullName = "";
    let shouldNavigateToDashboard =
      user?.data?.data?.should_navigate_to_dashboard;
    let isOrganizationPresent = user?.data.data.organisation_present;

    try {
      const userDetails = await axios.get(`${baseURL}/api/team-members`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      fullName = userDetails?.data?.data?.user?.fullName || "";
    } catch (detailsError: any) {
      console.warn("Failed to get user details:", detailsError?.message);
      // Continue without user details
    }

    // Attempt app verification with direct method if we have tokens
    if (authToken && orgToken) {
      try {
        console.log("Attempting app verification with direct method");
        await verifyAppDirect(authToken, orgToken);
        console.log("App verification attempted");
      } catch (verifyAppError: any) {
        console.warn(
          "App verification direct method failed:",
          verifyAppError?.message,
        );
        // Continue despite verification failure
      }
    }

    return {
      shouldNavigateToDashboard,
      token: authToken,
      refreshToken: user?.data?.data?.refreshToken,
      isVerified,
      fullName,
      isOrganizationPresent,
      orgToken,
    };
  } catch (error: any) {
    console.error(
      "Error during authentication:",
      error?.response?.data || error?.message,
    );
    throw error;
  }
}
