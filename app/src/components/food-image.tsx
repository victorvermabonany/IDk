import Image from "next/image";

export function FoodImage({
  alt,
  mealId,
  mealTitle,
  position = "50% 50%",
  priority = false,
  className = "",
  decorative = false,
}: {
  alt: string;
  mealId?: string;
  mealTitle?: string;
  position?: string;
  priority?: boolean;
  className?: string;
  decorative?: boolean;
}) {
  const mealImages: Record<string, string> = {
    "pesto-rigatoni": "/meal-pesto-rigatoni.png",
    "crispy-chicken-tacos": "/meal-crispy-chicken-tacos.png",
    "turkey-rice-bowls": "/meal-turkey-rice-bowls.png",
    "smoky-turkey-chili": "/meal-smoky-turkey-chili.png",
    "sausage-pepper-pan": "/meal-sausage-peppers.png",
    "turkey-tomato-rigatoni": "/meal-turkey-rigatoni.png",
    "bean-pepper-quesadillas": "/meal-black-bean-quesadillas.png",
    "tofu-rice-bowls": "/meal-tofu-rice-bowls.jpg",
    "lentil-tomato-bowls": "/meal-lentil-tomato-bowls.jpg",
    "chickpea-coconut-curry": "/meal-chickpea-coconut-curry.jpg",
    "sweet-potato-black-bean-tacos": "/meal-sweet-potato-black-bean-tacos.jpg",
    "mediterranean-chickpea-quinoa": "/meal-mediterranean-chickpea-quinoa.jpg",
    "tofu-quinoa-skillet": "/meal-tofu-quinoa-skillet.jpg",
    "lentil-rice-stuffed-peppers": "/meal-lentil-rice-pepper-bowls.jpg",
    "egg-quinoa-vegetable-bowls": "/meal-egg-quinoa-vegetable-bowls.jpg",
  };
  const title = mealTitle?.toLowerCase() ?? "";
  const imageFromTitle = title.includes("pesto rigatoni") ? "/meal-pesto-rigatoni.png"
    : title.includes("chicken tacos") ? "/meal-crispy-chicken-tacos.png"
    : title.includes("turkey rice bowls") ? "/meal-turkey-rice-bowls.png"
    : title.includes("turkey") && title.includes("chili") ? "/meal-smoky-turkey-chili.png"
    : title.includes("sausage") && title.includes("peppers") ? "/meal-sausage-peppers.png"
    : title.includes("turkey rigatoni") ? "/meal-turkey-rigatoni.png"
    : title.includes("black bean") && title.includes("quesadilla") ? "/meal-black-bean-quesadillas.png"
    : title.includes("tofu") && title.includes("rice") ? "/meal-tofu-rice-bowls.jpg"
    : title.includes("lentil") && title.includes("tomato") ? "/meal-lentil-tomato-bowls.jpg"
    : title.includes("chickpea") && title.includes("curry") ? "/meal-chickpea-coconut-curry.jpg"
    : title.includes("sweet potato") && title.includes("taco") ? "/meal-sweet-potato-black-bean-tacos.jpg"
    : title.includes("chickpea") && title.includes("quinoa") ? "/meal-mediterranean-chickpea-quinoa.jpg"
    : title.includes("tofu") && title.includes("quinoa") ? "/meal-tofu-quinoa-skillet.jpg"
    : title.includes("lentil") && title.includes("rice") ? "/meal-lentil-rice-pepper-bowls.jpg"
    : title.includes("egg") && title.includes("quinoa") ? "/meal-egg-quinoa-vegetable-bowls.jpg"
    : undefined;

  return (
    <div className={`food-image ${className}`}>
      <Image
        src={imageFromTitle ?? (mealId ? mealImages[mealId] : undefined) ?? "/weektable-dinners.png"}
        alt={decorative ? "" : alt}
        fill
        priority={priority}
        sizes="(max-width: 768px) 100vw, 60vw"
        style={{ objectFit: "cover", objectPosition: position }}
      />
    </div>
  );
}
