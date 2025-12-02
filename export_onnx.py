# export_simple.py
from stable_baselines3 import PPO
import torch

model = PPO.load("./models/ppo_dodge_shooter_final")

# Extract just the policy network
policy = model.policy

# Put in eval mode
policy.eval()

# Simple wrapper that takes a flat array
class FlatPolicy(torch.nn.Module):
    def __init__(self, policy):
        super().__init__()
        self.features = policy.features_extractor.extractors["obs"]
        self.mlp = policy.mlp_extractor.policy_net
        self.action = policy.action_net
        
    def forward(self, obs):
        x = self.features(obs)
        x = self.mlp(x)
        return self.action(x)

flat_policy = FlatPolicy(policy)
dummy_input = torch.randn(1, 28)

torch.onnx.export(
    flat_policy,
    dummy_input,
    "./trained_agent.onnx",
    input_names=["obs"],
    output_names=["action"],
    opset_version=11,
    do_constant_folding=True
)

print("✅ Exported to trained_agent.onnx")
