def define_env(env):
    "Make environment variables accessible"
    import os
    env.variables["HOSTNAME"] = os.getenv("HOSTNAME", "localhost")
