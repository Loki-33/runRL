from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv
from stable_baselines3 import PPO
import cv2
import numpy as np
import time

model = PPO.load("./models/ppo_dodge_shooter_final")

env = StableBaselinesGodotEnv(
    env_path="arc/yo.x86_64",
    port=11008,
    show_window=True,
    n_parallel=1,
    speedup=3
)


try:
    obs = env.reset()
    done = False
    
    while not done:
        # Take screenshot
        action, _ = model.predict(obs, deterministic=True)
        obs, reward, done, info = env.step(action)
        
        time.sleep(1/30)  # 30 FPS

except KeyboardInterrupt:
    pass

out.release()
env.close()



