import torch 
from godot_rl.core.godot_env import GodotEnv
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import CheckpointCallback, EvalCallback
from stable_baselines3.common.vec_env import SubprocVecEnv, VecMonitor
import os


def make_env(env_path, port, show_window=False, seed=0, speedup=8):
    def _init():
        env = GodotEnv(
            env_path=env_path,
            port=port,
            show_window=show_window,
            seed=seed,
            speedup=speedup
        )
        return env 
    return _init



def train(env_path, 
          n_parallel=4, 
          total_timesteps=2_000_000,
          save_freq=50_000,
          log_dir='./logs/',
          model_dir='./models/',
          speedup=8):
    os.makedirs(log_dir, exist_ok=True)
    os.makedirs(model_dir, exist_ok=True)

    print(f'Creating {n_parallel} environments....')
    base_port = 15000
    
    env = StableBaselinesGodotEnv(
        env_path=env_path,
        port=11008,
        show_window=True,  # Show first environment
        seed=0,
        n_parallel=n_parallel,
        speedup=speedup
    )

    
    env = VecMonitor(env, filename=os.path.join(log_dir, 'monitor'))

    print('ENV CREATED')

    print("Creating PPO model...")
    model = PPO(
        "MultiInputPolicy",
        env,
        learning_rate=3e-4,
        n_steps=2048,
        batch_size=512,
        n_epochs=10,
        gamma=0.99,
        gae_lambda=0.95,
        clip_range=0.2,
        clip_range_vf=None,
        ent_coef=0.01,  # Encourage exploration
        vf_coef=0.5,
        max_grad_norm=0.5,
        verbose=1,
        tensorboard_log=log_dir,
        policy_kwargs=dict(
            net_arch=[256, 256],  
            activation_fn=torch.nn.ReLU
        )
    )
    

    checkpoint_callback = CheckpointCallback(
        save_freq=save_freq // n_parallel,
        save_path=model_dir,
        name_prefix="ppo_dodge_shooter",
        save_replay_buffer=False,
        save_vecnormalize=False,
    )
    
    print(f"Starting training for {total_timesteps} timesteps...")
    print(f"Tensorboard logs: {log_dir}")
    print(f"Models will be saved to: {model_dir}")
    print("\nTo monitor training, run in another terminal:")
    print(f"tensorboard --logdir={log_dir}")
    
    model.learn(
        total_timesteps=total_timesteps,
        callback=[checkpoint_callback],
        progress_bar=True
    )
    
    # Save 
    final_path = os.path.join(model_dir, "ppo_dodge_shooter_final")
    model.save(final_path)
    print(f"\nTraining complete! Final model saved to: {final_path}")
    
    env.close()


if __name__ == '__main__':
    train(env_path='arc/yo.x86_64',
          n_parallel=4,
          total_timesteps=2000000,
          speedup=8)
