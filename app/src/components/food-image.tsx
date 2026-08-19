import Image from "next/image";

export function FoodImage({
  alt,
  mealId,
  imageKey,
  imageMatch,
  position = "50% 50%",
  priority = false,
  className = "",
  decorative = false,
}: {
  alt: string;
  mealId?: string;
  imageKey?: string;
  imageMatch?: "exact" | "category" | "fallback";
  position?: string;
  priority?: boolean;
  className?: string;
  decorative?: boolean;
}) {
  const imageSources: Record<string, string> = {
    "meal-pesto-rigatoni": "/meal-pesto-rigatoni.png",
    "meal-crispy-chicken-tacos": "/meal-crispy-chicken-tacos.png",
    "meal-turkey-rice-bowls": "/meal-turkey-rice-bowls.png",
    "meal-smoky-turkey-chili": "/meal-smoky-turkey-chili.png",
    "meal-sausage-peppers": "/meal-sausage-peppers.png",
    "meal-turkey-rigatoni": "/meal-turkey-rigatoni.png",
    "meal-black-bean-quesadillas": "/meal-black-bean-quesadillas.png",
    "meal-tofu-rice-bowls": "/meal-tofu-rice-bowls.jpg",
    "meal-lentil-tomato-bowls": "/meal-lentil-tomato-bowls.jpg",
    "meal-chickpea-coconut-curry": "/meal-chickpea-coconut-curry.jpg",
    "meal-sweet-potato-black-bean-tacos": "/meal-sweet-potato-black-bean-tacos.jpg",
    "meal-mediterranean-chickpea-quinoa": "/meal-mediterranean-chickpea-quinoa.jpg",
    "meal-tofu-quinoa-skillet": "/meal-tofu-quinoa-skillet.jpg",
    "meal-lentil-rice-pepper-bowls": "/meal-lentil-rice-pepper-bowls.jpg",
    "meal-egg-quinoa-vegetable-bowls": "/meal-egg-quinoa-vegetable-bowls.jpg",
  };
  const exactKeysByMealId: Record<string, string> = {
    "pesto-rigatoni": "meal-pesto-rigatoni", "crispy-chicken-tacos": "meal-crispy-chicken-tacos",
    "turkey-rice-bowls": "meal-turkey-rice-bowls", "smoky-turkey-chili": "meal-smoky-turkey-chili",
    "sausage-pepper-pan": "meal-sausage-peppers", "turkey-tomato-rigatoni": "meal-turkey-rigatoni",
    "bean-pepper-quesadillas": "meal-black-bean-quesadillas", "tofu-rice-bowls": "meal-tofu-rice-bowls",
    "lentil-tomato-bowls": "meal-lentil-tomato-bowls", "chickpea-coconut-curry": "meal-chickpea-coconut-curry",
    "sweet-potato-black-bean-tacos": "meal-sweet-potato-black-bean-tacos", "mediterranean-chickpea-quinoa": "meal-mediterranean-chickpea-quinoa",
    "tofu-quinoa-skillet": "meal-tofu-quinoa-skillet", "lentil-rice-stuffed-peppers": "meal-lentil-rice-pepper-bowls",
    "egg-quinoa-vegetable-bowls": "meal-egg-quinoa-vegetable-bowls",
  };
  const legacyExactKey = mealId ? exactKeysByMealId[mealId] : undefined;
  const selectedKey = imageMatch === "fallback" ? undefined : imageKey ?? (imageMatch === undefined ? legacyExactKey : undefined);
  const source = selectedKey ? imageSources[selectedKey] : undefined;

  return (
    <div className={`food-image ${className}`}>
      <Image
        src={source ?? "/weektable-dinners.png"}
        alt={decorative ? "" : alt}
        fill
        priority={priority}
        sizes="(max-width: 768px) 100vw, 60vw"
        style={{ objectFit: "cover", objectPosition: position }}
      />
    </div>
  );
}
