from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv
from stable_baselines3 import PPO
import time


model = PPO.load("./models/ppo_dodge_shooter_final")


env = StableBaselinesGodotEnv(
    env_path="arc/yo.x86_64",
    port=11008,
    show_window=True,  
    n_parallel=1,
    speedup=1  
)

try:
    episode = 1
    while True:
        obs = env.reset()
        done = False
        episode_reward = 0
        steps = 0
        hits = 0
        
        print(f"=== Episode {episode} ===")
        
        while not done:
            action, _ = model.predict(obs, deterministic=True)
            
            # Execute in game
            obs, reward, done, info = env.step(action)
            episode_reward += reward[0]
            steps += 1
        
        print(f"Reward: {episode_reward:.2f} | Steps: {steps} | Survived: {steps/60:.1f}s")
        print()
        
        episode += 1
        time.sleep(1) 

except KeyboardInterrupt:
    print("\nStopping...")

env.close()

