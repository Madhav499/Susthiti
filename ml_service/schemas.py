from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

YesNo = Literal["Yes", "No"]

# The exact 16 features the supplied model expects, in training order.
FEATURES: tuple[str, ...] = (
    "Age", "Gender", "Polyuria", "Polydipsia", "sudden weight loss", "weakness", "Polyphagia",
    "Genital thrush", "visual blurring", "Itching", "Irritability", "delayed healing",
    "partial paresis", "muscle stiffness", "Alopecia", "Obesity",
)


class PredictRequest(BaseModel):
    """Field names match the dataset columns exactly (aliases keep the spaces)."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    Age: int = Field(ge=1, le=120)
    Gender: Literal["Male", "Female"]
    Polyuria: YesNo
    Polydipsia: YesNo
    sudden_weight_loss: YesNo = Field(alias="sudden weight loss")
    weakness: YesNo
    Polyphagia: YesNo
    Genital_thrush: YesNo = Field(alias="Genital thrush")
    visual_blurring: YesNo = Field(alias="visual blurring")
    Itching: YesNo
    Irritability: YesNo
    delayed_healing: YesNo = Field(alias="delayed healing")
    partial_paresis: YesNo = Field(alias="partial paresis")
    muscle_stiffness: YesNo = Field(alias="muscle stiffness")
    Alopecia: YesNo
    Obesity: YesNo

    def as_features(self) -> dict:
        data = self.model_dump(by_alias=True)
        return {name: data[name] for name in FEATURES}


class PredictResponse(BaseModel):
    prediction: Literal["Positive", "Negative"]
    classification_probability: float | None
    model_version: str
